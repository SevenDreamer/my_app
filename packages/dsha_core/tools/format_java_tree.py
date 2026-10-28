# 版权来源：DSHA（MIT）tools/format-java-tree.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""Run the pinned formatter over an explicit, complete inventory in package batches.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出；
FORMATTER 指向同目录 format_java.py。
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))
SETS = ("main", "low", "standard", "debug", "androidTest", "test")
SOURCE = "java/com/deepseekharness/app"
MANIFEST = ROOT / "tools/java-format-files.json"
LOCK = ROOT / "tools/java-format.lock.json"
FORMATTER = Path(__file__).with_name('format_java.py')
REPORT_DIR = ROOT / "app/build/java-format"
MAX_BATCH = 256
TOOL_SOURCE = "tools/java-format/JavaTokenFingerprint.java"
EXCLUDED_PARTS = frozenset(("history", "upstream", "vendor", "third_party", "third-party", "generated"))
GENERATED_OWNERS = {
    "app/src/main/java/com/deepseekharness/app/util/BuiltinPluginRegistry.java":
        "tools/generate-builtin-plugins.py",
    "app/src/main/java/com/deepseekharness/app/util/CredentialPathRules.java":
        "tools/generate-credential-paths.py",
}


class TreeFormatError(Exception):
    pass


def digest(path: Any) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def inventory(root: Any = ROOT, protected: Any = (), generated: Any = ()) -> list[str]:
    protected = set(protected)
    generated = set(generated)
    result: list[str] = []
    for source_set in SETS:
        directory = root / "app/src" / source_set / SOURCE
        if not directory.is_dir():
            raise TreeFormatError("FORMAT_SOURCE_SET_MISSING: " + str(directory))
        for path in directory.rglob("*.java"):
            relative = path.relative_to(root).as_posix()
            if EXCLUDED_PARTS.intersection(path.relative_to(directory).parts):
                continue
            if relative in protected or relative in generated:
                continue
            if path.is_symlink() or not path.is_file():
                raise TreeFormatError("FORMAT_SOURCE_LINK_OR_NONFILE: " + relative)
            result.append(relative)
    if TOOL_SOURCE not in protected:
        if not (root / TOOL_SOURCE).is_file():
            raise TreeFormatError("FORMAT_TOOL_SOURCE_MISSING")
        result.append(TOOL_SOURCE)
    return sorted(result)


def declared_files(manifest: Any) -> list[str]:
    data = json.loads(Path(manifest).read_text(encoding="utf-8"))
    files = data.get("files")
    if data.get("schema") != 1 or not isinstance(files, list) or any(
            not isinstance(name, str) for name in files
    ):
        raise TreeFormatError("FORMAT_MANIFEST_SCHEMA")
    if len(files) != len(set(files)):
        raise TreeFormatError("FORMAT_MANIFEST_DUPLICATE")
    return files


def batch_key(name: str) -> tuple[str, str]:
    if name == TOOL_SOURCE:
        return ("tools", "java-format")
    parts = Path(name).parts
    if len(parts) < 8 or parts[:2] != ("app", "src") or parts[2] not in SETS:
        raise TreeFormatError("FORMAT_UNEXPECTED_SOURCE: " + name)
    if parts[3:7] != ("java", "com", "deepseekharness", "app"):
        raise TreeFormatError("FORMAT_UNEXPECTED_PACKAGE: " + name)
    return (parts[2], parts[7] if len(parts) > 8 else "(root)")


def package_batches(names: list[str]) -> list[tuple[tuple[str, str], list[str]]]:
    groups: dict[tuple[str, str], list[str]] = defaultdict(list)
    for name in names:
        groups[batch_key(name)].append(name)
    batches: list[tuple[tuple[str, str], list[str]]] = []
    for key in sorted(groups):
        group = sorted(groups[key])
        for offset in range(0, len(group), MAX_BATCH):
            batches.append((key, group[offset:offset + MAX_BATCH]))
    return batches


def run_formatter(mode: str, names: list[str], number: int, java: str | None, offline: bool, phase: str) -> dict[str, Any]:
    report = REPORT_DIR / f"tree-{phase}-{number:02d}.json"
    command = [sys.executable, str(FORMATTER), mode, "--files", *names,
               "--report", str(report)]
    if java:
        command += ["--java", java]
    if offline:
        command.append("--offline")
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if completed.returncode not in ((0, 1) if mode == "--check" else (0,)):
        raise TreeFormatError(
            f"FORMAT_BATCH_FAILED {number}: {completed.stderr.strip()}\n{completed.stdout[-2000:]}")
    evidence = json.loads(report.read_text(encoding="utf-8"))
    if [entry["file"] for entry in evidence["files"]] != names:
        raise TreeFormatError("FORMAT_BATCH_REPORT_MISMATCH")
    return evidence


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--plan", action="store_true")
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--write", action="store_true")
    parser.add_argument("--java", help="JDK 17 java executable")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args(argv)
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    generated = lock.get("generatedFiles", [])
    if set(generated) != set(GENERATED_OWNERS):
        raise TreeFormatError("FORMAT_GENERATED_OWNER_REGISTRY_MISMATCH")
    for name, owner in GENERATED_OWNERS.items():
        if not (ROOT / name).is_file() or not (ROOT / owner).is_file():
            raise TreeFormatError("FORMAT_GENERATED_OWNER_MISSING: " + name)
    expected = inventory(protected=lock["protectedFiles"], generated=generated)
    declared = declared_files(MANIFEST)
    missing = sorted(set(expected) - set(declared))
    extra = sorted(set(declared) - set(expected))
    selected = expected if args.plan else declared
    batches = package_batches(selected)
    print(f"owned Java: {len(expected)}; manifest: {len(declared)}; "
          f"missing: {len(missing)}; extra: {len(extra)}; batches: {len(batches)}")
    print("generator-owned Java excluded: " + ", ".join(sorted(generated)))
    for key, names in batches:
        print(f"{key[0]}/{key[1]}: {len(names)}")
    if args.plan:
        return 0
    if missing or extra:
        raise TreeFormatError("FORMAT_MANIFEST_INCOMPLETE: update the explicit adoption list")
    if not batches or any(len(names) > MAX_BATCH for _, names in batches):
        raise TreeFormatError("FORMAT_BATCH_SIZE")
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    snapshot = {name: digest(ROOT / name) for name in selected}
    checks = [run_formatter("--check", names, n, args.java, args.offline, "preflight")
              for n, (_, names) in enumerate(batches, 1)]
    if args.write:
        if any(digest(ROOT / name) != value for name, value in snapshot.items()):
            raise TreeFormatError("FORMAT_SOURCE_CHANGED_DURING_PREFLIGHT")
        reports = []
        for n, (_, names) in enumerate(batches, 1):
            if any(digest(ROOT / name) != snapshot[name] for name in names):
                raise TreeFormatError("FORMAT_SOURCE_CHANGED_BEFORE_WRITE")
            reports.append(run_formatter("--write", names, n, args.java, args.offline, "write"))
        # The fixed formatter's post-write SHA and exact javac token digest are authoritative.
        for evidence in reports:
            for entry in evidence["files"]:
                if digest(ROOT / entry["file"]) != entry["formattedSha256"]:
                    raise TreeFormatError("FORMAT_WRITTEN_BYTES_MISMATCH: " + entry["file"])
    else:
        reports = checks
    changed = sum(entry["needsFormatting"] for report in reports for entry in report["files"])
    summary = {
        "schema": 1, "mode": "write" if args.write else "check",
        "tool": lock["tool"], "version": lock["version"], "artifactSha256": lock["sha256"],
        "files": len(selected), "batches": len(batches), "needsFormatting": changed,
        "protectedExcluded": lock["protectedFiles"],
        "reports": [f"tree-{'write' if args.write else 'preflight'}-{n:02d}.json"
                    for n in range(1, len(batches) + 1)],
    }
    (REPORT_DIR / "tree-summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"pinned Java formatter: {len(selected)} files, {changed} need formatting")
    return 1 if args.check and changed else 0


if __name__ == "__main__":
    if sys.flags.optimize:
        raise SystemExit("FORMAT_OPTIMIZATION_FORBIDDEN")
    try:
        raise SystemExit(main())
    except TreeFormatError as error:
        print(error, file=sys.stderr)
        raise SystemExit(2)

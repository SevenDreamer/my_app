# 版权来源：DSHA（MIT）app/src/main/assets/plugin-capabilities.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Bounded informational capability evidence. Never imports or executes the inspected package."""
from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any

MAX_FILE = 1024 * 1024
MAX_TOTAL = 8 * 1024 * 1024
MAX_FILES = 256
VERSION = 1


def analyze(root: Any, package: dict[str, Any], *, candidate_sha: str = '', lock_sha: str = '',
            resolved: Any = ()) -> dict[str, Any]:
    root = Path(root).resolve()
    files: list[dict[str, str]] = []
    unknown = ['patch references and dynamically loaded modules are not followed']
    total = 0
    inputs: dict[str, str] = {}
    client: list[str] = []

    def read(relative: str) -> bytes:
        nonlocal total
        if not isinstance(relative, str) or not relative or len(relative) > 1024:
            raise ValueError('path')
        parts = Path(relative).parts
        if Path(relative).is_absolute() or '\\' in relative or ':' in relative or '..' in parts:
            raise ValueError('path')
        file = root
        for part in parts:
            file = file / part
            if stat.S_ISLNK(os.lstat(file).st_mode):
                raise ValueError('link')
        info = os.lstat(file)
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_FILE or len(inputs) >= MAX_FILES or total + info.st_size > MAX_TOTAL:
            raise ValueError('budget')
        directory_fds: list[int] = []
        try:
            if os.open in os.supports_dir_fd:
                directory_fds.append(os.open(root, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0) | getattr(os, 'O_NOFOLLOW', 0)))
                for part in parts[:-1]:
                    directory_fds.append(os.open(part, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0) | getattr(os, 'O_NOFOLLOW', 0), dir_fd=directory_fds[-1]))
                fd = os.open(parts[-1], os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0), dir_fd=directory_fds[-1])
            else:
                fd = os.open(file, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0))
        finally:
            for directory_fd in reversed(directory_fds):
                os.close(directory_fd)
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode) or (before.st_dev, before.st_ino, before.st_size) != (info.st_dev, info.st_ino, info.st_size):
                raise ValueError('changed')
            data = stream.read(MAX_FILE + 1)
            after = os.fstat(stream.fileno())
        if len(data) > MAX_FILE or (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns) or len(data) != before.st_size:
            raise ValueError('changed')
        total += len(data)
        inputs[relative] = hashlib.sha256(data).hexdigest()
        return data

    def label(value: Any) -> str:
        return re.sub(r'(?:sk-|Bearer\s+)\S+', '[redacted]', str(value), flags=re.I).replace('\n', ' ').replace('\r', ' ')[:120]

    try:
        if json.loads(read('package.json')) != package:
            unknown.append('package changed during inspection')
    except (OSError, ValueError, UnicodeError):
        unknown.append('package input not inspected')
    declared = (package.get('dsh') or {}).get('client') or {}
    for value in declared.get('inject', []) if isinstance(declared, dict) and isinstance(declared.get('inject', []), list) else []:
        if isinstance(value, str):
            client.append(label(value))
        else:
            unknown.append('non-literal client inject')
    entries: list[str] = []
    for entry in (package.get('main'), (package.get('cordis') or {}).get('entry')):
        if isinstance(entry, str) and entry not in entries:
            entries.append(entry)
    if not entries:
        unknown.append('no declared server entry')
    for entry in entries:
        try:
            files.append(dict(file=entry, source=read(entry).decode('utf8')))
        except (OSError, ValueError, UnicodeError):
            unknown.append('entry not inspected: ' + label(entry))
    script_map = package.get('scripts') or {}
    if not isinstance(script_map, dict):
        unknown.append('invalid script declaration')
        script_map = {}
    scripts = sorted(label(k) for k in script_map if isinstance(k, str))[:100]
    pnpmfiles: list[str] = []
    for entry in ('.pnpmfile.cjs', 'pnpmfile.cjs'):
        if os.path.lexists(root / entry):
            pnpmfiles.append(entry)
    dependency_scripts = 0
    inspected_manifests = 0
    if not resolved and any(package.get(key) for key in ('dependencies', 'peerDependencies', 'optionalDependencies')):
        unknown.append('dependency scripts were not inspected')
    for row in resolved:
        if not isinstance(row, dict) or not isinstance(row.get('path'), str):
            unknown.append('dependency script coverage incomplete')
            continue
        if not row['path']:
            continue  # The root package's declarations are already shown separately.
        try:
            pkg = json.loads(read(row['path'].rstrip('/') + '/package.json'))
            dependency_scripts += len(pkg.get('scripts') or {})
            inspected_manifests += 1
        except (OSError, ValueError, UnicodeError):
            unknown.append('dependency manifest coverage incomplete')
    here = Path(__file__).resolve().parent
    try:
        result = subprocess.run(['node', '--max-old-space-size=96', str(here / 'plugin-capabilities.cjs')],
                                input=json.dumps(dict(files=files)), capture_output=True, text=True, timeout=8, check=True)
        ast = json.loads(result.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        ast = dict(findings=[], unknown=['AST parser unavailable or budget exceeded'], parser='acorn@8.15.0')
    ast['unknown'] = list(dict.fromkeys(unknown + list(ast.get('unknown', []))))[:200]
    # 分析器自证摘要：本模块（现代化后文件名）+ 两个随包 JS 助手的字节。
    parser_files = ['plugin_capabilities.py', 'plugin-capabilities.cjs', 'plugin-acorn.cjs']
    analyzer_sha = hashlib.sha256(b''.join((here / name).read_bytes() for name in parser_files)).hexdigest()
    return dict(format=VERSION, analyzerSha256=analyzer_sha, candidateSha256=candidate_sha, dependencyLockSha256=lock_sha,
                inputSha256=hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest(),
                clientInject=client[:100], scripts=scripts, pnpmfiles=pnpmfiles, dependencyScriptCount=dependency_scripts,
                inspectedDependencyManifests=inspected_manifests, inspectedFiles=len(inputs), inspectedBytes=total, **ast)

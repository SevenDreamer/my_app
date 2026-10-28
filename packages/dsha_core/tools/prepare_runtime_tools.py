# 版权来源：DSHA（MIT）tools/prepare-runtime-tools.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""生成宿主和 guest 共用的已锁定工具身份。

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

from source_text import write_text as write_source_text, matches_text
import argparse
import json
import os
from pathlib import Path
import re
from typing import Any

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))


def build(root: Any) -> str:
    data = json.loads((root / "tools/runtime-tools.lock.json").read_text(encoding="utf-8"))
    if data.get("schema") != 1:
        raise ValueError("RUNTIME_TOOLS_SCHEMA")
    for key in ("pnpm", "certifi"):
        row = data[key]
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){2}", row["version"]) \
                or not re.fullmatch(r"[a-f0-9]{64}", row["sha256"]):
            raise ValueError("RUNTIME_TOOLS_IDENTITY")
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    value = build(ROOT)
    target = ROOT / "app/src/main/assets/runtime-tools.json"
    if args.check:
        if not target.is_file() or target.read_bytes() != value.encode("utf-8"):
            raise SystemExit("RUNTIME_TOOLS_DRIFT: run tools/prepare_runtime_tools.py")
    else:
        write_source_text(target, value, encoding="utf-8")
    print("PASS runtime tools identity")


if __name__ == "__main__":
    main()

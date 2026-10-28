# 版权来源：DSHA（MIT）tools/source_text.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Deterministic generated-text writer, compatible with Python 3.9.

Only controls the writer's newline translation. Existing package/recipe CR bytes
are not silently normalized; original tar/npm bytes remain the caller's bytes.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any


def write_text(path: Any, value: str, encoding: str = 'utf-8') -> int:
    with Path(path).open('w', encoding=encoding, newline='\n') as output:
        return output.write(value)


def matches_text(path: Any, value: str, encoding: str = 'utf-8') -> bool:
    target = Path(path)
    return target.is_file() and target.read_bytes() == value.encode(encoding)

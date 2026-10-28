# 版权来源：DSHA（MIT）tools/device_script_privacy.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Redact explicitly selected device and local tool paths from runner output."""
from __future__ import annotations

from typing import Any


def redact(value: Any, identifiers: Any) -> Any:
    if isinstance(value, dict):
        return {key: redact(item, identifiers) for key, item in value.items()}
    if isinstance(value, list):
        return [redact(item, identifiers) for item in value]
    if not isinstance(value, str):
        return value
    for identifier in identifiers:
        if identifier:
            value = value.replace(str(identifier), "[local selection]")
    return value

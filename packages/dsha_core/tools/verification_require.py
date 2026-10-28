# 版权来源：DSHA（MIT）tools/verification_require.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""发布门禁的显式断言；Python -O 不得删掉检查。"""
from __future__ import annotations

from typing import Any


def require(condition: Any, message: str = "VERIFICATION_FAILED") -> None:
    if not condition:
        raise RuntimeError(str(message))

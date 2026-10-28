# 版权来源：DSHA（MIT）tools/check-release-prerequisites.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""无密钥地检查正式发布身份；不能替代软件/签名/真机回执。

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))
identity = json.loads((ROOT / "ci/release-identity.json").read_text(encoding="utf-8"))
if identity.get("schema") != 1 or identity.get("packageName") != "dsh.android.client" \
        or not re.fullmatch(r"[a-f0-9]{64}", identity.get("certificateSha256", "")) \
        or identity.get("schemes") != ["v1", "v2", "v3"]:
    raise SystemExit("RELEASE_IDENTITY_INVALID")
print("PASS release identity; signing keys, complete software receipt and physical acceptance remain separate requirements")

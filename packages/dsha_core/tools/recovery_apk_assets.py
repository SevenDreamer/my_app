# 版权来源：DSHA（MIT）tools/recovery_apk_assets.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""核对签名 APK 内的应急归档存储映射，兼容原先独立存放的历史包。"""
from __future__ import annotations

import hashlib
import json
import zipfile
from typing import Any

SHARED = {'recovery-rootfs.bin': 'offline-rootfs.bin', 'recovery-dsh-runtime.bin': 'dsh-runtime.bin'}


def archive_locations(apk: zipfile.ZipFile, descriptor: dict[str, Any], require_locations: bool = False) -> dict[str, str]:
    pinned = descriptor['archives']
    if len(pinned) != 2 or {row['asset'] for row in pinned} != set(SHARED):
        raise ValueError('RECOVERY_ARCHIVE_SET')
    name = 'assets/recovery-asset-locations.json'
    if name in apk.namelist():
        if apk.getinfo(name).file_size > 8192:
            raise ValueError('RECOVERY_ARCHIVE_SOURCE_LIMIT')
        mapping = json.loads(apk.read(name))
        if mapping['schema'] != 1 or mapping['runtimeId'] != descriptor['id']:
            raise ValueError('RECOVERY_ARCHIVE_SOURCE_ID')
        rows = mapping['archives']
    else:
        if require_locations:
            raise ValueError('RECOVERY_ARCHIVE_SOURCE_MISSING')
        rows = [dict(**row, source=row['asset']) for row in pinned]
    if len(rows) != len(pinned):
        raise ValueError('RECOVERY_ARCHIVE_SOURCE_COUNT')
    hashes = {row['asset']: row['sha256'] for row in pinned}
    sources: dict[str, str] = {}
    for row in rows:
        logical, source = row['asset'], row['source']
        if logical not in SHARED or logical in sources or source not in (logical, SHARED[logical]):
            raise ValueError('RECOVERY_ARCHIVE_SOURCE')
        if row['sha256'] != hashes[logical]:
            raise ValueError('RECOVERY_ARCHIVE_SOURCE_HASH')
        with apk.open('assets/' + source) as stream:
            h = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                h.update(chunk)
        if h.hexdigest() != hashes[logical]:
            raise ValueError('RECOVERY_ARCHIVE_HASH')
        sources[logical] = source
    return sources

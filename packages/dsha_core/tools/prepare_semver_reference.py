# 版权来源：DSHA（MIT）tools/prepare-semver-reference.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Exact official SemVer differential input; never modify the DSH raw fixture.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import tarfile
import urllib.request
from typing import Any

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))


def prepare(check: bool = False) -> Any:
    lock = json.loads((ROOT / 'tools/semver-reference.lock.json').read_text(encoding='utf8'))
    if lock.get('schema') != 1 or lock.get('name') != 'semver' or lock.get('version') != '7.8.1' or not lock['url'].startswith('https://registry.npmjs.org/semver/'):
        raise ValueError('SEMVER_REFERENCE_LOCK')
    store = ROOT / 'app/build/semver-reference'
    archive = store / 'semver-7.8.1.tgz'
    store.mkdir(parents=True, exist_ok=True)
    if not archive.is_file():
        if check:
            raise ValueError('SEMVER_REFERENCE_NOT_PREPARED')
        with urllib.request.urlopen(lock['url'], timeout=30) as response:
            archive.write_bytes(response.read(1024 * 1024))
    data = archive.read_bytes()
    expected = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
    if expected != lock['integrity']:
        raise ValueError('SEMVER_REFERENCE_INTEGRITY')
    members: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as source:
        for item in source:
            if item.isdir():
                continue
            if not item.isfile() or not item.name.startswith('package/') or '..' in item.name.split('/') or '\\' in item.name or item.size > 1024 * 1024:
                raise ValueError('SEMVER_REFERENCE_MEMBER')
            relative = item.name[8:]
            if relative in members:
                raise ValueError('SEMVER_REFERENCE_DUPLICATE')
            member_file = source.extractfile(item)
            if member_file is None:
                raise ValueError('SEMVER_REFERENCE_MEMBER')
            members[relative] = member_file.read()
    folder = store / 'package'
    if folder.is_symlink():
        raise ValueError('SEMVER_REFERENCE_ROOT_LINK')
    if check:
        actual = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file() or p.is_symlink()}
        if actual != set(members):
            raise ValueError('SEMVER_REFERENCE_MEMBERS_CHANGED')
        for name, data in members.items():
            target = folder / name
            if target.is_symlink() or target.read_bytes() != data:
                raise ValueError('SEMVER_REFERENCE_BYTES_CHANGED:' + name)
    else:
        for name, data in members.items():
            target = folder / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_symlink():
                raise ValueError('SEMVER_REFERENCE_LINK')
            target.write_bytes(data)
        return prepare(True)
    return folder


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true')
    args = p.parse_args()
    print('PASS official byte-exact SemVer7.8.1 reference:', prepare(args.check))

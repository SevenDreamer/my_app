# 版权来源：DSHA（MIT）tools/prepare-browser-react-reference.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""Prepare byte-verified React 18 browser test files outside signed assets.

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
STORE = ROOT / 'app/build/browser-react-reference'
LOCK = ROOT / 'tools/browser-react-reference.lock.json'


def prepare(check: bool = False) -> Any:
    lock = json.loads(LOCK.read_text(encoding='utf8'))
    if lock.get('schema') != 1 or len(lock.get('packages', [])) != 2:
        raise ValueError('BROWSER_REACT_LOCK')
    for package in lock['packages']:
        name, version = package['name'], package['version']
        if (name, version) not in {('react', '18.3.1'), ('react-dom', '18.3.1')}:
            raise ValueError('BROWSER_REACT_PACKAGE')
        archive = STORE / (name + '-' + version + '.tgz')
        if not archive.is_file():
            if check:
                raise ValueError('BROWSER_REACT_NOT_PREPARED:' + name)
            STORE.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(package['url'], timeout=40) as response:
                archive.write_bytes(response.read(10 * 1024 * 1024 + 1))
        data = archive.read_bytes()
        if len(data) > 10 * 1024 * 1024 or 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode() != package['integrity']:
            raise ValueError('BROWSER_REACT_INTEGRITY:' + name)
        member = 'package/' + package['file']
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as source:
            item = source.getmember(member)
            if not item.isfile() or item.size > 5 * 1024 * 1024:
                raise ValueError('BROWSER_REACT_MEMBER:' + name)
            member_file = source.extractfile(item)
            if member_file is None:
                raise ValueError('BROWSER_REACT_MEMBER:' + name)
            expected = member_file.read()
        target = STORE / name / package['file']
        if target.is_symlink():
            raise ValueError('BROWSER_REACT_LINK:' + name)
        if check:
            if not target.is_file() or target.read_bytes() != expected:
                raise ValueError('BROWSER_REACT_BYTES:' + name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(expected)
    return STORE


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    print('PASS byte-verified React browser test reference:', prepare(args.check))

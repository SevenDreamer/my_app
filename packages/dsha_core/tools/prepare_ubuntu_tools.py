# 版权来源：DSHA（MIT）tools/prepare-ubuntu-tools.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""把已由 Ubuntu 签名索引锁定的 ARM64 deb 包生成为离线安装资产。

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import argparse
import concurrent.futures
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import tarfile
import time
import urllib.request
from typing import Any

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))
LOCK = ROOT / 'tools/ubuntu-tools/packages.lock.json'


def digest(path: Any) -> str:
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def inputs() -> dict[str, str]:
    # 我们仓的 snake_case 移植名按原版文件名入账（key 逐字保留原版相对路径）。
    original_names = {'prepare_ubuntu_tools.py': 'prepare-ubuntu-tools.py'}

    def key_of(path: Path) -> str:
        try:
            return path.relative_to(ROOT).as_posix()
        except ValueError:
            return 'tools/' + original_names.get(path.name, path.name)

    return {key_of(p): digest(p) for p in (Path(__file__), LOCK)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'app/build/ubuntu-tools-cache')
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--configured-overlay', type=Path)
    parser.add_argument('--configured-proof', type=Path)
    args = parser.parse_args()
    cache = args.cache.resolve()
    cache.relative_to(ROOT / 'app/build')
    cache.mkdir(parents=True, exist_ok=True)
    lock = json.loads(LOCK.read_text())
    if lock['format'] != 1 or lock['architecture'] != 'arm64':
        raise ValueError('不支持的 Ubuntu 工具锁')
    rows = lock['packages']
    if args.configured_overlay:
        if not args.configured_proof:
            raise ValueError('预安装工具缺少制备证明')
        prepared = args.configured_overlay.resolve()
        prepared.relative_to(ROOT / 'app/build')
        proof = json.loads(args.configured_proof.read_text(encoding='utf-8'))
        if proof.get('layout') != 'configured-overlay-v1' or proof.get('archiveSha256') != digest(prepared) or proof.get('packageLockSha256') != digest(LOCK):
            raise ValueError('预安装工具与当前锁不一致')
        with tarfile.open(prepared, 'r:gz') as archive:
            members = archive.getmembers()
            for member in members:
                name = member.name.removeprefix('./')
                if name.startswith('/') or '..' in name.split('/') or not (name in ('root', 'etc', 'usr', 'var', 'var/lib', 'var/cache', 'root/.dsha-ubuntu-tools-version') or name.startswith(('etc/', 'usr/', 'var/lib/', 'var/cache/'))):
                    raise ValueError('预安装工具路径越界:' + name)
            status_file = archive.extractfile('var/lib/dpkg/status')
            if status_file is None:
                raise ValueError('预安装工具缺少 dpkg 状态')
            status = status_file.read()
            if hashlib.sha256(status).hexdigest() != proof.get('statusSha256'):
                raise ValueError('dpkg 状态摘要不一致')
            packages: dict[str, Any] = {}
            for paragraph in status.decode().split('\n\n'):
                item = dict(line.split(': ', 1) for line in paragraph.splitlines() if ': ' in line and not line.startswith(' '))
                if 'Package' in item:
                    packages[item['Package']] = item
            for item in rows:
                actual = packages.get(item['Package'], {})
                if actual.get('Version') != item['Version'] or actual.get('Status') != 'install ok installed':
                    raise ValueError('工具尚未配置:' + item['Package'])
            version_file = archive.extractfile('root/.dsha-ubuntu-tools-version')
            if version_file is None or version_file.read().decode().strip() != digest(LOCK):
                raise ValueError('工具版本标记不一致')
        output = ROOT / 'app/src/main/assets/ubuntu-tools.bin'
        shutil.copyfile(prepared, output)
        metadata = {'inputs': inputs(), 'archive_sha256': digest(output), 'installed_bytes': sum(int(r['Installed-Size']) * 1024 for r in rows), 'base_status_sha256': lock['baseStatusSha256'], 'packages': len(rows), 'layout': 'configured-overlay-v1', 'status_sha256': proof['statusSha256']}
        output.with_suffix('.inputs.json').write_text(json.dumps(metadata, indent=2) + '\n')
        (output.parent / 'ubuntu-tools.layout').write_text('configured-overlay-v1\n', encoding='ascii')
        (output.parent / 'ubuntu-tools.manifest.json').write_text(json.dumps({'schema': 1, 'archiveSha256': metadata['archive_sha256'], 'statusSha256': proof['statusSha256'], 'packageLockSha256': digest(LOCK), 'packages': len(rows)}, indent=2) + '\n')
        print(json.dumps({'layout': metadata['layout'], 'archiveBytes': output.stat().st_size, 'configuredPackages': len(rows)}))
        return
    if len({r['Package'] for r in rows}) != len(rows):
        raise ValueError('工具包重复')

    def fetch(row: dict[str, Any]) -> Path:
        relative = row['Filename']
        if not relative.startswith('pool/main/') or '..' in relative.split('/') or not re.fullmatch(r'[A-Za-z0-9_./+~%-]+', relative):
            raise ValueError('软件包路径无效')
        if row['Architecture'] not in ('arm64', 'all'):
            raise ValueError('软件包架构不符')
        target = cache / Path(relative).name
        if not target.is_file() or digest(target) != row['SHA256']:
            if args.offline:
                raise ValueError('离线缓存缺少：' + target.name)
            temporary = target.with_suffix('.part')
            urls = ['https://ports.ubuntu.com/ubuntu-ports/' + relative,
                    # pool 轮转会删旧版本（pin-rot）；Launchpad 永久档保原字节（SHA 校验不变）。
                    'https://launchpad.net/ubuntu/+archive/primary/+files/' + Path(relative).name]
            last: Exception | None = None
            for attempt in range(2):
                for url in urls:
                    try:
                        with urllib.request.urlopen(url, timeout=40) as response:
                            temporary.write_bytes(response.read())
                        break
                    except Exception as error:  # noqa: BLE001 - 逐源重试，全部失败才报
                        last = error
                        time.sleep(2 * (attempt + 1))
                else:
                    continue
                break
            else:
                raise ValueError('Ubuntu 软件包下载失败：' + target.name) from last
            if temporary.stat().st_size != int(row['Size']) or digest(temporary) != row['SHA256']:
                temporary.unlink()
                raise ValueError('Ubuntu 软件包摘要不符：' + target.name)
            temporary.replace(target)
        return target
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as workers:
        files = list(workers.map(fetch, rows))
    output = ROOT / 'app/src/main/assets/ubuntu-tools.bin'
    temporary = output.with_suffix('.tmp')
    with temporary.open('wb') as raw, gzip.GzipFile(fileobj=raw, filename='', mode='wb', mtime=0, compresslevel=1) as compressed:
        with tarfile.open(fileobj=compressed, mode='w|', format=tarfile.PAX_FORMAT) as archive:
            for file in files:
                item = tarfile.TarInfo(file.name)
                item.mode = 0o600
                item.size = file.stat().st_size
                with file.open('rb') as stream:
                    archive.addfile(item, stream)
            for name, data in {
                    'SHA256SUMS': ''.join(r['SHA256'] + '  ' + f.name + '\n' for r, f in zip(rows, files)),
                    'packages.txt': ' '.join(r['Package'] for r in rows) + '\n',
                    'version.txt': digest(LOCK) + '\n',
            }.items():
                value = data.encode()
                item = tarfile.TarInfo(name)
                item.mode = 0o600
                item.size = len(value)
                archive.addfile(item, io.BytesIO(value))
    temporary.replace(output)
    metadata = {'inputs': inputs(), 'archive_sha256': digest(output),
                'installed_bytes': sum(int(r['Installed-Size']) * 1024 for r in rows),
                'base_status_sha256': lock['baseStatusSha256'], 'packages': len(rows)}
    output.with_suffix('.inputs.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (output.parent / 'ubuntu-tools.layout').write_text('deb-install-v1\n', encoding='ascii')
    print(json.dumps({'archiveBytes': output.stat().st_size, **metadata}))


if __name__ == '__main__':
    main()

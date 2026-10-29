"""Build the adb-wheels.bin offline wheel bundle from the upstream wheel lock.

adb-wheels 是离线 wheel 集（AdbBridge 消费：tar.gz 形态、成员=顶层 .whl 文件、
解到 stage/wheels 后按 adb-wheels.lock.json 逐 wheel SHA 核对合并）。钉源 =
DSHA 仓内锁文件（wheel 文件名 + SHA-256），本工具只负责按锁取料（PyPI
files.pythonhosted.org 永久留存）、验摘要、确定性重封（gzip mtime=0、成员名字
典序）。锁内 archiveSha256 是上游自有归档的指纹，本工具自烘归档不受其约束
（wheel 级 SHA 才是合并核对契约）。
"""

import argparse
import gzip
import hashlib
import io
import json
import os
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # my_app 仓根（tools→dsha_core→packages→仓根）


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def wheel_url(name: str, digest: str) -> str:
    """PyPI JSON API 解析精确下载地址（文件名即钉值，逐字匹配）。"""
    pkg, version = name.split('-', 2)[:2]
    api = f'https://pypi.org/pypi/{pkg}/{version}/json'
    with urllib.request.urlopen(api, timeout=60) as response:
        meta = json.load(response)
    for item in meta['urls']:
        if item['filename'] == name:
            return item['url']
    raise ValueError('PyPI 无此 wheel 文件：' + name)


def fetch(name: str, digest: str, cache: Path) -> bytes:
    path = cache / name
    if path.is_file():
        data = path.read_bytes()
        if sha(data) == digest:
            return data
        path.unlink()
    last: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(wheel_url(name, digest), timeout=120) as response:
                data = response.read()
            break
        except Exception as error:  # noqa: BLE001
            last = error
    else:
        raise ValueError('wheel 下载失败：' + name) from last
    if sha(data) != digest:
        raise ValueError('wheel 摘要不匹配：' + name)
    cache.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', type=Path, required=True, help='adb-wheels.lock.json（钉源）')
    parser.add_argument('--cache', type=Path, default=ROOT / 'app/build/adb-wheels-cache')
    parser.add_argument('--output', type=Path, default=ROOT / 'android/app/src/main/assets/adb-wheels.bin')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    lock = json.loads(args.lock.read_text(encoding='utf-8'))
    wheels: dict[str, str] = lock['wheels']
    bodies: dict[str, bytes] = {}
    for name in sorted(wheels):
        bodies[name] = fetch(name, wheels[name], args.cache)
        print('wheel ok：' + name, file=sys.stderr)

    with gzip.GzipFile(filename='', mode='wb', fileobj=open(args.output, 'wb'), mtime=0) as gz:
        # GNU 格式：spake2 全限定 wheel 名超 ustar 100 字节上限（上游 Linux tar 同款）。
        with tarfile.open(fileobj=gz, mode='w', format=tarfile.GNU_FORMAT) as out:
            for name in sorted(bodies):
                info = tarfile.TarInfo(name)
                info.size = len(bodies[name])
                info.mtime = 0
                info.mode = 0o644
                out.addfile(info, io.BytesIO(bodies[name]))
    data = args.output.read_bytes()
    print({'archiveBytes': len(data), 'sha256': sha(data), 'wheels': len(bodies)})


if __name__ == '__main__':
    main()

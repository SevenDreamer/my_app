"""Build the glibc-python.tar.gz runtime asset from pinned Ubuntu arm64 debs.

glibc-python.tar.gz 是场外预烘制品（仓库无生成器）。自烘方案：Ubuntu noble
python3.12 依赖闭包 deb 的 data.tar 合并重封——布局契约取自 RootfsInstaller.java：
usr/bin/python3.12 + usr/lib/python3.12/**（python-support.bin 再补 libsqlite3/
libreadline soname）。纯 Python（ar + compression.zstd + tarfile）跨宿主。
DEB_PINS 为我们的自选钉版（DSHA 私有制品无可对照源）。
"""

import argparse
import gzip
import hashlib
import io
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # my_app 仓根（tools→dsha_core→packages→仓根）

# 我们的自选钉版：noble arm64 python3.12 依赖闭包（filename → sha256）。
# 来源 ports.ubuntu.com Packages 索引（3.12.3-1ubuntu0.17 现行版）。
DEB_PINS: dict[str, str] = {
    'libbz2-1.0_1.0.8-5.1ubuntu0.1_arm64.deb': '1a92811105f89bf948a629de99715ef23941ef93c901e0942883029069db3f94',
    'libdb5.3t64_5.3.28+dfsg2-7_arm64.deb': 'b04d246b871e2e745538fa71ce2d1a127dfd65e7b1438bc6b8e2bb86538f519e',
    'libexpat1_2.6.1-2ubuntu0.6_arm64.deb': '9782206e359ccd50dd5686c2fd5182ed87c777a6d76b0269e38e89dbaac9f3b2',
    'libffi8_3.4.6-1build1_arm64.deb': 'a4d4607144bc599328a913d7312761fd8f4a650d67c7d5058f1f3667d771d37c',
    'liblzma5_5.6.1+really5.4.5-1ubuntu0.4_arm64.deb': 'a1b42103a0fcf3264c3a124cf20ed89d593b8e27dfb6e05e71a0fe7504da827b',
    'libncursesw6_6.4+20240113-1ubuntu2_arm64.deb': 'b301f776112fadae74852adb953e9b3f8ce5f896a4b927a916b402e51d8b08a9',
    'libpython3.12-minimal_3.12.3-1ubuntu0.17_arm64.deb': '11790e3fc5deb4867c7fb762aa5f4f710093501f62b60ef16dd427ea2495bcc6',
    'libpython3.12-stdlib_3.12.3-1ubuntu0.17_arm64.deb': 'b9462bf2f55bfffaf304a597c7964354e0d49ab20eed028f55f7183f2210581e',
    'libpython3.12t64_3.12.3-1ubuntu0.17_arm64.deb': '9e9c6f862540ecb99e495cc8b67373c9f53cff635c3b1d56db3cc6fa47bfd3a1',
    'libssl3t64_3.0.13-0ubuntu3_arm64.deb': 'd2207f12435060893997880a34d7ed91d14e163862d5d1394d51918d0723d7e0',
    'libtinfo6_6.4+20240113-1ubuntu2_arm64.deb': 'e8d06277be81d0f6e7d49ce796a477a9fc88e755bf3048e0afe44fc14a310b72',
    'python3.12-minimal_3.12.3-1ubuntu0.17_arm64.deb': 'be39fa8380f1e65fc02701cdbc8652acd924d8576b4ba1bd772141040a22b15f',
    'zlib1g_1.3.dfsg-3.1ubuntu2_arm64.deb': '66aaebb68401a88b4f70a5f48e1a516b611fdcaae15208d8aee677c556d2cf01',
}
PIN_PREFIXES = {
    'libbz2-1.0': 'pool/main/b/bzip2/',
    'libdb5.3t64': 'pool/main/d/db5.3/',
    'libexpat1': 'pool/main/e/expat/',
    'libffi8': 'pool/main/libf/libffi/',
    'liblzma5': 'pool/main/x/xz-utils/',
    'libncursesw6': 'pool/main/n/ncurses/',
    'libpython3.12-minimal': 'pool/main/p/python3.12/',
    'libpython3.12-stdlib': 'pool/main/p/python3.12/',
    'libpython3.12t64': 'pool/main/p/python3.12/',
    'libssl3t64': 'pool/main/o/openssl/',
    'libtinfo6': 'pool/main/n/ncurses/',
    'python3.12-minimal': 'pool/main/p/python3.12/',
    'zlib1g': 'pool/main/z/zlib/',
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fetch(name: str, cache: Path) -> bytes:
    path = cache / name
    if path.is_file():
        data = path.read_bytes()
        if sha(data).startswith(DEB_PINS[name][:12]):
            return data
        path.unlink()
    package = name.split('_', 1)[0]
    relative = PIN_PREFIXES[package] + name
    urls = ['https://ports.ubuntu.com/ubuntu-ports/' + relative,
            'https://launchpad.net/ubuntu/+archive/primary/+files/' + name]
    last: Exception | None = None
    for attempt in range(2):
        for url in urls:
            try:
                with urllib.request.urlopen(url, timeout=60) as response:
                    data = response.read()
                break
            except Exception as error:  # noqa: BLE001
                last = error
        else:
            continue
        break
    else:
        raise ValueError('deb 下载失败：' + name) from last
    if not sha(data).startswith(DEB_PINS[name][:12]):
        raise ValueError('deb 摘要不匹配：' + name)
    path.write_bytes(data)
    return data


def deb_data(data: bytes, name: str) -> list[tuple[tarfile.TarInfo, bytes | None]]:
    """ar 解 deb、zstd 解 data.tar、返回（成员头, 文件体）流。"""
    if data[:8] != b'!<arch>\n':
        raise ValueError('不是 ar 归档：' + name)
    pos = 8
    for _ in range(8):
        if pos + 60 > len(data):
            break
        header = data[pos:pos + 60]
        fname = header[:16].decode('ascii', 'replace').strip()
        size = int(header[48:58].decode().strip())
        body = data[pos + 60:pos + 60 + size]
        pos += 60 + size + (size & 1)
        if fname.startswith('data.tar'):
            kind = fname.split('.')[-1]
            if kind == 'zst':
                import compression.zstd as zstd  # noqa: PLC0415 - Python 3.14 stdlib
                body = zstd.decompress(body)
            elif kind == 'xz':
                import lzma  # noqa: PLC0415
                body = lzma.decompress(body)
            elif kind == 'gz':
                body = gzip.decompress(body)
            stream = io.BytesIO(body)
            out: list[tuple[tarfile.TarInfo, bytes | None]] = []
            with tarfile.open(fileobj=stream) as tar:
                for info in tar:
                    body: bytes | None = None
                    if info.isfile():  # 链接只透传头（deb 间共享 doc 硬链，字面保留）
                        fileobj = tar.extractfile(info)
                        body = fileobj.read() if fileobj is not None else None
                    out.append((info, body))
            return out
    raise ValueError('deb 无 data.tar：' + name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'app/build/glibc-python-cache')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/dsha/glibc-python.tar.gz')
    args = parser.parse_args()
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    # 合并顺序按 DEB_PINS 字典序（stdlib 在 minimal 之后覆盖共享路径，dpkg 语义无重叠）。
    merged: dict[str, tuple[tarfile.TarInfo, bytes | None]] = {}
    for name in sorted(DEB_PINS):
        for info, body in deb_data(fetch(name, cache), name):
            key = info.name.lstrip('./')
            if key:
                merged[key] = (info, body)
        print('deb ok：' + name, file=sys.stderr)

    with gzip.GzipFile(filename='', mode='wb', fileobj=open(args.output, 'wb'), mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode='w', format=tarfile.USTAR_FORMAT) as out:
            for key in sorted(merged):
                info, body = merged[key]
                name = key
                info.name = name
                info.mtime = 0
                if info.isfile() and body is not None:
                    out.addfile(info, io.BytesIO(body))
                elif info.isdir():
                    info.size = 0
                    out.addfile(info)
                elif info.issym() or info.islnk():
                    info.size = 0
                    out.addfile(info)
                # 其余（设备等）跳过：容器里不需要
    data = args.output.read_bytes()
    print({'archiveBytes': len(data), 'sha256': sha(data), 'files': len(merged)})


if __name__ == '__main__':
    main()

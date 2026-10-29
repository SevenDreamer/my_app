"""Build the offline-rootfs.bin base rootfs asset from pinned inputs.

offline-rootfs.bin 是场外预烘制品（仓库无生成器）。自烘方案 = ubuntu-base
（官方基底，SHA 钉值）+ Node 24 LTS arm64 官方发行包铺 /usr/local（dsh 住
/usr/local/lib/node_modules，npm prefix 对齐）+ 无多余标记（部署链在安装期
注入 /root/.dsh/adb 脚本）。gzip mtime=0 输出确定性，纯 Python 跨宿主。
"""

import argparse
import gzip
import hashlib
import io
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # my_app 仓根（tools→dsha_core→packages→仓根）

UBUNTU_BASE = ('ubuntu-base-24.04.5-base-arm64.tar.gz',
               'a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2',
               'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz')
NODE_DIST = ('node-v24.16.0-linux-arm64.tar.xz',
             '524659219d6a207a7400f2bde15d19ba060ffbe0d32a8643319ad67e3bb64c78',
             'https://nodejs.org/dist/v24.16.0/node-v24.16.0-linux-arm64.tar.xz')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fetch(entry: tuple[str, str, str], cache: Path) -> bytes:
    name, pin, url = entry
    path = cache / name
    if path.is_file() and sha(path.read_bytes()) == pin:
        return path.read_bytes()
    with urllib.request.urlopen(url, timeout=300) as response:
        data = response.read()
    if sha(data) != pin:
        raise ValueError('下载摘要不匹配：' + name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'app/build/runtime-downloads')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/dsha/offline-rootfs.bin')
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    base = io.BytesIO(fetch(UBUNTU_BASE, args.cache))
    node = io.BytesIO(fetch(NODE_DIST, args.cache))
    merged: dict[str, tuple[tarfile.TarInfo, bytes | None]] = {}

    with tarfile.open(fileobj=base) as tar:
        for info in tar:
            name = info.name.lstrip('./')
            if not name:
                continue
            # 链接只透传头（ubuntu-base 有 linkname 带双斜杠的怪 hardlink，字面保留）。
            body = None
            if info.isfile():
                stream = tar.extractfile(info)
                body = stream.read() if stream is not None else None
            merged[name] = (info, body)

    with tarfile.open(fileobj=node) as tar:  # tar.xz：tarfile 透明解 xz
        for info in tar:
            parts = info.name.lstrip('./').split('/', 1)
            if len(parts) != 2 or not parts[1]:
                continue
            # node 发行包顶层目录剥一层：bin/lib/include/share 铺到 /usr/local。
            name = 'usr/local/' + parts[1]
            body = None
            if info.isfile():
                stream = tar.extractfile(info)
                body = stream.read() if stream is not None else None
            merged[name] = (info, body)

    with gzip.GzipFile(filename='', mode='wb', fileobj=open(args.output, 'wb'), mtime=0) as gz:
        with tarfile.open(fileobj=gz, mode='w', format=tarfile.USTAR_FORMAT) as out:
            for name in sorted(merged):
                info, body = merged[name]
                info.name = name
                info.mtime = 0
                info.uid = info.gid = 0
                info.uname = info.gname = 'root'
                if info.isfile() and body is not None:
                    info.size = len(body)
                    out.addfile(info, io.BytesIO(body))
                elif info.isdir():
                    info.size = 0
                    out.addfile(info)
                elif info.issym() or info.islnk():
                    info.size = 0
                    out.addfile(info)
    data = args.output.read_bytes()
    print({'archiveBytes': len(data), 'sha256': sha(data), 'entries': len(merged),
           'node_in_rootfs': 'usr/local/bin/node' in merged, 'bash_in_rootfs': 'bin/bash' in merged})


if __name__ == '__main__':
    main()

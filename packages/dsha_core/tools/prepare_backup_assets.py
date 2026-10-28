# 版权来源：DSHA（MIT）tools/prepare-backup-assets.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""从已锁定的 dsh 覆盖层生成包来源证明；只排除内容及文件位完全一致的可重建依赖。

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

from source_text import write_text as write_source_text, matches_text
from pathlib import Path
import tarfile
import hashlib
import json
import os
import sys
from typing import Any

root = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))
archive = root / 'app/src/main/assets/dsh-runtime.bin'
prefix = 'usr/local/lib/node_modules/@deepseek-ai/dsh/node_modules/'
records: dict[str, list[tuple[str, str]]] = {}
with tarfile.open(archive, 'r:gz') as tar:
    for item in tar:
        if not item.name.startswith(prefix):
            continue
        rel = item.name[len(prefix):]
        parts = rel.split('/')
        count = 2 if parts[0].startswith('@') else 1
        if len(parts) <= count:
            continue
        name = '/'.join(parts[:count])
        path = '/'.join(parts[count:])
        if item.isfile():
            sha = hashlib.sha256()
            stream = tar.extractfile(item)
            if stream is None:
                raise ValueError('unsupported package entry')
            binary: Any = stream
            with binary:
                for chunk in iter(lambda: binary.read(1024 * 1024), b''):
                    sha.update(chunk)
            value = path + '\0FILE\0' + str(item.mode & 0o777) + '\0' + sha.hexdigest() + '\n'
        elif item.issym():
            value = path + '\0LINK\0' + item.linkname + '\n'
        elif item.isdir():
            continue
        else:
            raise ValueError('unsupported package entry')
        records.setdefault(name, []).append((path, value))
proofs = {name: hashlib.sha256(''.join(value for path, value in sorted(rows, key=lambda row: row[0].encode('utf-16be'))).encode()).hexdigest() for name, rows in records.items()}
output = {'version': 1, 'archiveSha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'packages': dict(sorted(proofs.items()))}
target = root / 'app/src/main/assets/managed-package-proofs.json'
content = json.dumps(output, ensure_ascii=False, indent=2) + '\n'
args = sys.argv[1:]
if args == ['--check']:
    if not matches_text(target, content, encoding='utf8'):
        raise SystemExit('受管依赖证明与当前归档不一致；先运行 tools/prepare_backup_assets.py --write 并审阅改动')
elif args == [] or args == ['--write']:
    write_source_text(target, content, encoding='utf8')
else:
    raise SystemExit('usage: prepare_backup_assets.py [--check|--write]')
print('managed package proofs:', len(proofs))

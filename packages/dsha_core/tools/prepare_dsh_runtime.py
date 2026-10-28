# 版权来源：DSHA（MIT）tools/prepare-dsh-runtime.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""按仓库锁文件安装 Linux arm64 依赖，并生成已适配的离线覆盖层。

现代化改动（行为契约不变）：资产根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出；
builder 由 importlib 互载改为同目录显式导入（模块名 build_dsh_runtime）。
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

from source_text import write_text as write_source_text, matches_text

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, default=ROOT / 'app/build/locked-dsh-runtime')
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--offline', action='store_true', help='仅使用已填充的 npm 缓存，缺包直接失败')
    args = parser.parse_args()
    work = args.work.resolve()
    if ROOT / 'app/build' not in work.parents:
        parser.error('npm 安装目录必须位于本项目 app/build 下')
    work.mkdir(parents=True, exist_ok=True)
    for name in ('package.json', 'package-lock.json'):
        shutil.copyfile(ROOT / 'tools/dsh-runtime' / name, work / name)
    npm = shutil.which('npm.cmd') or shutil.which('npm')
    if not npm:
        parser.error('需要 Node 24 和 npm 11')
    command = [npm, 'ci', '--prefix', str(work), '--os=linux', '--cpu=arm64', '--libc=glibc',
               '--ignore-scripts', '--no-audit', '--no-fund']
    if args.cache:
        command += ['--cache', str(args.cache.resolve())]
    if args.offline:
        command.append('--offline')
    subprocess.run(command, check=True)
    # 原版经 importlib 互载 build-dsh-runtime；显式导入同目录模块。
    import build_dsh_runtime as builder
    version = json.loads((ROOT / 'tools/dsh-runtime/package.json').read_text(encoding='utf-8'))['dependencies']['@deepseek-ai/dsh']
    report = builder.build(work / 'node_modules', ROOT / 'app/src/main/assets/dsh-runtime.bin', version)
    write_source_text(work / 'build-report.json', json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('新版离线覆盖层已生成：', report['sha256'])


if __name__ == '__main__':
    main()

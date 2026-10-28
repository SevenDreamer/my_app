# 版权来源：DSHA（MIT）tools/prepare-destructive-policy.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
#!/usr/bin/env python3
"""Materialize the mandatory policy's classifier from its one canonical builtin source.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))


def prepare(check: bool = False) -> None:
    assets = ROOT / 'app/src/main/assets'
    for name in ('destructive.js', 'workdir.js'):
        source = assets / 'builtin-plugins/dsh-destructive-guard/lib' / name
        target = assets / 'destructive-policy' / name
        data = source.read_bytes()
        if check:
            if not target.is_file() or target.read_bytes() != data:
                raise SystemExit('DESTRUCTIVE_POLICY_COPY_CHANGED: ' + name)
        else:
            target.write_bytes(data)
    print('PASS byte-exact mandatory policy classifier copies')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    prepare(parser.parse_args().check)

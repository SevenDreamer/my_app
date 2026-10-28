# 版权来源：DSHA（MIT）tools/ci-toolchain.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Read CI tool versions only after checking the source build configuration.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
from typing import Any

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))
FIELDS = ('java', 'node', 'python', 'gradle', 'agp', 'androidPlatform', 'buildTools', 'ndk')


def one(pattern: str, content: str, label: str) -> str:
    values = re.findall(pattern, content)
    if len(values) != 1:
        raise ValueError('CI_TOOLCHAIN_SOURCE: ' + label)
    return values[0]


def read(root: Any = ROOT) -> dict[str, str]:
    lock = json.loads((root / 'ci/toolchain.lock.json').read_text(encoding='utf-8'))
    if lock.get('schema') != 1 or set(lock) != {'schema', *FIELDS}:
        raise ValueError('CI_TOOLCHAIN_SCHEMA')
    for name in FIELDS:
        if not isinstance(lock[name], str) or not re.fullmatch(r'[A-Za-z0-9.-]+', lock[name]):
            raise ValueError('CI_TOOLCHAIN_VALUE: ' + name)
    app = (root / 'app/build.gradle').read_text(encoding='utf-8')
    top = (root / 'build.gradle').read_text(encoding='utf-8')
    wrapper = (root / 'gradle/wrapper/gradle-wrapper.properties').read_text(encoding='utf-8')
    platform = one(r'version\s*=*\s*release\(\s*(\d+)\s*\)', app, 'compileSdk')
    expected = {
        'java': one(r'sourceCompatibility\s+JavaVersion.VERSION_(\d+)', app, 'java'),
        'gradle': one(r'distributionUrl=[^\n]+/gradle-([0-9.]+)-bin\.zip', wrapper, 'gradle'),
        'agp': one(r"id\s+'com.android.application'\s+version\s+'([0-9.]+)'", top, 'agp'),
        'ndk': one(r"ndkVersion\s+['\"]([0-9.]+)['\"]", app, 'ndk'),
        'androidPlatform': 'android-' + platform + '.0',
    }
    if one(r'targetSdk\s+(\d+)', app, 'targetSdk') != platform:
        raise ValueError('CI_TOOLCHAIN_TARGET_SDK')
    for name, value in expected.items():
        if lock[name] != value:
            raise ValueError('CI_TOOLCHAIN_DRIFT: ' + name)
    return lock


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--field', choices=FIELDS)
    parser.add_argument('--github-output', action='store_true')
    args = parser.parse_args()
    lock = read()
    if args.github_output:
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8', newline='\n') as output:
            for name in FIELDS:
                output.write(name + '=' + lock[name] + '\n')
    elif args.field:
        print(lock[args.field])
    else:
        print(json.dumps(lock, sort_keys=True))


if __name__ == '__main__':
    main()

# 版权来源：DSHA（MIT）tools/release_names.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Release APKs are grouped by their download version, independent of diagnostics.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import os
from pathlib import Path
import re
from typing import Any

from release_layout import checked_path

ROOT = Path(os.environ.get('DSHA_SOURCE_ROOT', str(Path(__file__).resolve().parents[1])))


def _version(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,100}', value):
        raise ValueError('DELIVERY_APK_NAME_VERSION')
    return value


def apk_name_version(root: Any = ROOT) -> str:
    build = (Path(root) / 'app/build.gradle').read_text(encoding='utf-8')
    match = re.search(r"ext\.dshaApkNameVersion\s*=\s*['\"]([^'\"]+)['\"]", build)
    if not match:
        match = re.search(r'versionName\s+"([^"]+)"', build)
    if not match:
        raise ValueError('DELIVERY_APK_NAME_VERSION')
    return _version(match[1])


def apk_filename(flavor: str, root: Any = ROOT) -> str:
    if flavor not in ('standard', 'low'):
        raise ValueError('DELIVERY_FLAVOR')
    return f'dsha-{apk_name_version(root)}{"low" if flavor == "low" else ""}.apk'


def apk_version_from_filename(name: str) -> str:
    """Read only the conventional APK name, including historical names."""
    if not isinstance(name, str) or Path(name).name != name:
        raise ValueError('DELIVERY_APK_FILENAME')
    if name.endswith('.apk.sha256'):
        name = name[:-7]
    if not name.startswith('dsha-') or not name.endswith('.apk'):
        raise ValueError('DELIVERY_APK_FILENAME')
    value = name[5:-4]
    if value.endswith('low'):
        value = value[:-3]
    return _version(value)


def _workspace_path(root: Any, *parts: str) -> Path:
    workspace = Path(root).resolve()
    result = workspace.joinpath(*parts)
    return checked_path(result, workspace)


def release_directory(root: Any = ROOT, version: str | None = None) -> Path:
    return _workspace_path(root, 'release', _version(version or apk_name_version(root)))


def apk_delivery_path(flavor: str, root: Any = ROOT) -> Path:
    return _workspace_path(root, 'release', apk_name_version(root), apk_filename(flavor, root))


def _build_code(value: int) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 1:
        raise ValueError('DELIVERY_VERSION_CODE')
    return value


def source_directory(version_code: int, root: Any = ROOT) -> Path:
    return _workspace_path(root, 'artifacts', 'source', f'build{_build_code(version_code)}')


def delivery_receipt_path(version_code: int, root: Any = ROOT) -> Path:
    return _workspace_path(root, 'artifacts', 'deliveries', f'build{_build_code(version_code)}.json')


def release_staging_directory(root: Any = ROOT) -> Path:
    return _workspace_path(root, 'artifacts', 'release-staging')

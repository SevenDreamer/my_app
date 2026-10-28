# 版权来源：DSHA（MIT）tools/release_acceptance.py —— 现代化重构，行为契约不变。
# 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
"""Select required device behaviors from actual changes against a sealed source baseline.

现代化改动（行为契约不变）：仓库根可用环境变量 DSHA_SOURCE_ROOT 指向 DSHA 检出。
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
from pathlib import Path
from typing import Any

from release_layout import ROOT, source_snapshot_path

CONTRACT = Path(__file__).with_name('release-acceptance.json')
CERT = 'e7e3a31a75946f2669194c972b3dd0c9aea3fc7c50a8b885d2dee710b22a53f5'


def digest(path: Any) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def baseline_from_receipt(path: Any, root: Any = ROOT) -> tuple[dict[str, Any], dict[str, str]]:
    """A raw current snapshot is not a baseline: require a completed two-flavor delivery receipt."""
    path = Path(path).resolve()
    receipt = json.loads(path.read_text(encoding='utf8'))
    if receipt.get('status') != 'PASS_FOR_EXECUTED_SCOPE':
        raise ValueError('ACCEPTANCE_BASELINE_NOT_DELIVERED')
    apks = receipt.get('apks', [])
    if len(apks) != 2 or {a.get('flavor') for a in apks} != {'standard', 'low'} \
            or any(a.get('certificateSha256') != CERT or a.get('package') != 'dsh.android.client' for a in apks):
        raise ValueError('ACCEPTANCE_BASELINE_IDENTITY')
    source = receipt.get('sourceSnapshot', {})
    snapshot = source_snapshot_path(source.get('path', ''), source.get('sha256'), root)
    return json.loads(snapshot.read_text(encoding='utf8')), {'receiptSha256': digest(path), 'sourceSha256': digest(snapshot)}


def requirements(baseline: dict[str, Any], current: dict[str, Any], contract: Any = CONTRACT,
                 provenance: Any = None) -> dict[str, Any]:
    rules = json.loads(Path(contract).read_text(encoding='utf8'))
    if rules.get('schema') != 1 or not isinstance(baseline, dict) or not isinstance(current, dict):
        raise ValueError('ACCEPTANCE_BASELINE_FORMAT')
    if not baseline or not current:
        raise ValueError('ACCEPTANCE_BASELINE_EMPTY')
    changed = sorted(name for name in set(baseline) | set(current) if baseline.get(name) != current.get(name))
    selected = {flavor: set(rules['baseDeviceChecks']) for flavor in ('standard', 'low')}
    matched: list[dict[str, Any]] = []
    for rule in rules['changeRules']:
        hits = [name for name in changed if any(fnmatch.fnmatchcase(name, pattern) for pattern in rule['paths'])]
        if not hits:
            continue
        matched.append({'rule': rule['id'], 'paths': hits})
        for flavor in rule['flavors']:
            selected[flavor].update(rule['deviceChecks'])
    return {'schema': 1, 'contractSha256': digest(contract), 'baselineReceipt': provenance,
            'baselineSha256': hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest(),
            'changed': changed, 'rules': matched, 'required': {k: sorted(v) for k, v in selected.items()}}


def validate(proof: dict[str, Any], selection: dict[str, Any]) -> None:
    if not isinstance(proof, dict) or proof.get('acceptance') != selection:
        raise ValueError('DEVICE_ACCEPTANCE_PLAN_MISMATCH')
    for flavor, checks in selection['required'].items():
        tested = proof.get('flavors', {}).get(flavor, {})
        behaviors = tested.get('behaviors', {})
        for check in checks:
            row = behaviors.get(check)
            if not isinstance(row, dict) or row.get('result') != 'PASS' \
                    or not isinstance(row.get('evidence'), str) or not row['evidence'].strip():
                raise ValueError('DEVICE_ACCEPTANCE_MISSING:' + flavor + ':' + check)

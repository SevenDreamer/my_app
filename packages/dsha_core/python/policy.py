#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 版权来源：DSHA（MIT）app/src/main/assets/device-shell-policy.py —— 现代化重构，行为契约不变。
"""执行原生侧验证的设备操作计划；路径与进程信息从同一设备连接现场读取。

计划来自原生白名单桥（version=1，kind∈READ/FILE/STOP/VIRTUAL_SCREEN）。
对外符号：Blocked（126 语义）/ argv_command（入口白名单）/ execute（分派执行）。
所有 Blocked 文案是宿主可解析契约，逐字保留。
"""
from __future__ import annotations

import posixpath
import re
import shlex
from typing import Any, Callable


class Blocked(Exception):
    """策略拦截（退出码 126）；命令根本没执行。"""


def argv_command(argv: list[str]) -> str:
    """入口白名单：仅 /system/bin/<合法名>，参数 NUL 检查 + shlex.quote。"""
    if not argv or not all(isinstance(value, str) and '\0' not in value for value in argv):
        raise Blocked('执行计划缺少有效参数')
    name = argv[0]
    if not re.fullmatch(r'[a-zA-Z0-9_.-]+', name):
        raise Blocked('执行计划包含未知入口')
    return ' '.join(shlex.quote(value) for value in ['/system/bin/' + name] + argv[1:])


def normalize(path: str, rules: dict[str, Any]) -> str:
    """别名路径归一到 /storage/emulated/0，并折叠运行时挂载前缀。"""
    path = posixpath.normpath(path)
    for alias in rules['aliases']:
        if path == alias or path.startswith(alias + '/'):
            return '/storage/emulated/0' + path[len(alias):]
    return re.sub(r'^/mnt/runtime/(default|read|write|full)/emulated/', '/storage/emulated/', path)


def write_allowed(path: str, rules: dict[str, Any]) -> bool:
    """写路径门：绝对路径、无通配/控制符/..、临时区或存储区且不碰保护区。"""
    if not path.startswith('/') or any(c in path for c in '\0*?[]\r\n') or '..' in path.split('/'):
        return False
    path = normalize(path, rules)
    if path.startswith(rules['temporary'] + '/'):
        return True
    match = re.fullmatch(rules['storage'], path)
    if not match or not match[1] or match[1] == '/':
        return False
    suffix = match[1].lower()
    for root in rules['protected']:
        if suffix == root or suffix.startswith(root + '/') or root.startswith(suffix + '/'):
            return False
    return True


def checked(result: Any) -> str:
    """现场读取必须成功；失败即拦截（拒绝带出不完整现场）。"""
    if result.exit_code != 0:
        raise Blocked('设备信息读取失败，未执行写入或结束应用：' + result.output[-240:])
    return result.output


def sms_roots(rules: dict[str, Any]) -> list[list[str]]:
    """短信数据库根（原生 plan 注入），逐项核验后返回小写分段。"""
    roots = rules.get('smsReadRoots')
    if (not isinstance(roots, list) or not roots or len(roots) > 32
            or any(not isinstance(root, str) or not root.startswith('/')
                   or '..' in root.split('/') or '\\' in root or '\0' in root for root in roots)):
        raise Blocked('SMS_ROOTS_UNVERIFIED')
    return [root.lower().strip('/').split('/') for root in roots]


def sms_provider_path(path: str, rules: dict[str, Any]) -> bool:
    """路径是否落在短信数据库根内。"""
    normalized = posixpath.normpath(path.replace('\\', '/')).lower()
    if not normalized.startswith('/'):
        return False
    parts = normalized.strip('/').split('/') if normalized != '/' else []
    return any(len(parts) >= len(root) and all(pattern == '*' or pattern == value
               for pattern, value in zip(root, parts)) for root in sms_roots(rules))


def sms_provider_descendant(path: str, rules: dict[str, Any]) -> bool:
    """路径是否以短信数据库根为前缀（递归操作时的后代判定）。"""
    normalized = posixpath.normpath(path.replace('\\', '/')).lower()
    if not normalized.startswith('/'):
        return False
    parts = normalized.strip('/').split('/') if normalized != '/' else []
    return any(all(pattern == '*' or pattern == value for pattern, value in zip(root, parts))
               for root in sms_roots(rules))


def root_read_paths(plan: dict[str, Any]) -> list[str]:
    """从 READ/FILE 计划抽取需要核验的读取路径。"""
    argv, kind = plan.get('argv', []), plan.get('kind')
    if kind == 'FILE' and argv and argv[0] == 'cp':
        return list(plan.get('operands', []))[:-1]
    if kind != 'READ' or not argv or argv[0] not in {
            'cat', 'head', 'tail', 'wc', 'grep', 'stat', 'readlink', 'realpath', 'du', 'ls',
            'find', 'md5sum', 'sha1sum', 'sha256sum', 'sha512sum'}:
        return []
    result, after_separator = [], False
    for arg in argv[1:]:
        if not after_separator and arg == '--':
            after_separator = True
            continue
        if not after_separator and arg.startswith('-'):
            if arg.startswith('--') and '=' in arg:
                arg = arg.split('=', 1)[1]
            elif len(arg) > 2 and arg[2] == '/':
                arg = arg[2:]
            else:
                continue
        if arg.startswith('/') or '/' in arg or not arg.startswith('-'):
            result.append(arg)
    if not result and argv[0] == 'du':
        result.append('.')
    if not result and argv[0] == 'ls' and root_read_may_descend(plan):
        result.append('.')
    return result


def root_read_may_descend(plan: dict[str, Any]) -> bool:
    """命令是否会递归下探（find/du/递归 ls/grep/递归 cp）。"""
    argv, kind = plan.get('argv', []), plan.get('kind')
    if not argv:
        return False
    command = argv[0]
    if kind == 'FILE' and command == 'cp':
        for arg in argv[1:]:
            if arg == '--':
                break
            if arg.startswith('-') and ('r' in arg or 'R' in arg):
                return True
        return False
    if kind != 'READ':
        return False
    if command in ('find', 'du'):
        return True
    if command in ('ls', 'grep'):
        for arg in argv[1:]:
            if arg in ('-R', '-r', '--recursive'):
                return True
            if arg.startswith('-') and not arg.startswith('--') and ('r' in arg or 'R' in arg):
                return True
    return False


def validate_root_reads(plan: dict[str, Any], shell: Callable[[str], Any]) -> None:
    """Root 读取路径逐个 readlink -f 核验；短信数据库路径一律拦截。"""
    rules = plan.get('paths', {})
    recursive = root_read_may_descend(plan)
    for value in root_read_paths(plan):
        if sms_provider_path(value, rules) or recursive and sms_provider_descendant(value, rules):
            raise Blocked('短信数据库仅允许经原生授权的当前用户 content query')
        path = normalize(value, rules) if value.startswith('/') else value
        resolved = checked(shell(argv_command(['readlink', '-f', '--', path]))).strip()
        if (not resolved.startswith('/') or '\n' in resolved or sms_provider_path(resolved, rules)
                or recursive and sms_provider_descendant(resolved, rules)):
            raise Blocked('Root 读取路径属于短信数据库或无法核验')


def check_path(path: str, rules: dict[str, Any], shell: Callable[[str], Any]) -> tuple[str, str]:
    """逐级核验写路径：拒符号链接、解析实际路径、复核保护区；返回 (归一路径, 类型)。"""
    if not write_allowed(path, rules):
        raise Blocked('受保护目录只读：' + path)
    path = normalize(path, rules)
    missing: list[str] = []
    current = path
    kind = 'MISSING'
    canonical = None
    # 元数据命令由代码生成；路径始终经过 shlex.quote，不拼接用户的 shell 程序。
    while current != '/':
        q = shlex.quote(current)
        script = ('if [ -L ' + q + ' ]; then printf "LINK\\n"; '
                  'elif [ -e ' + q + ' ]; then if [ -d ' + q + ' ]; then printf "DIR\\n"; '
                  'else printf "FILE\\n"; fi; /system/bin/readlink -f -- ' + q + '; '
                  'else printf "MISSING\\n"; fi')
        rows = checked(shell(script)).splitlines()
        if not rows or rows[0] not in ('LINK', 'DIR', 'FILE', 'MISSING'):
            raise Blocked('路径元数据无法确认')
        if rows[0] == 'LINK':
            raise Blocked('写入路径包含符号链接：' + current)
        if current == path:
            kind = rows[0]
        if rows[0] == 'MISSING':
            if canonical is not None:
                raise Blocked('目录在检查期间发生变化')
            missing.insert(0, posixpath.basename(current))
        elif canonical is None:
            if len(rows) != 2 or not rows[1].startswith('/'):
                raise Blocked('无法解析实际路径')
            canonical = posixpath.join(rows[1], *missing) if missing else rows[1]
            if not write_allowed(canonical, rules):
                raise Blocked('实际路径属于受保护目录：' + canonical)
        parent = posixpath.dirname(current)
        if not write_allowed(parent, rules):
            break
        current = parent
    if canonical is None:
        # mkdir -p 的所有新层都不存在时，仍需核对最近的已有祖先。
        parent = posixpath.dirname(current)
        real = checked(shell(argv_command(['readlink', '-f', '--', parent]))).strip()
        if not real.startswith('/') or '\n' in real or not write_allowed(posixpath.join(real, *missing), rules):
            raise Blocked('无法确认新目录的实际位置')
    return path, kind


def check_tree(path: str, kind: str, shell: Callable[[str], Any]) -> None:
    """目录整树符号链接扫描（rm/rmdir/mv 目标必须干净）。"""
    if kind == 'DIR':
        links = checked(shell(argv_command(['find', path, '-type', 'l', '-print', '-quit'])))
        if links.strip():
            raise Blocked('目录中包含符号链接，请缩小操作范围或使用实际路径')


def validate_files(plan: dict[str, Any], shell: Callable[[str], Any]) -> None:
    """FILE 计划：cp/mv 校验源与目标，rm/rmdir/mkdir/touch 校验目标树。"""
    paths, rules, op = plan['operands'], plan['paths'], plan['argv'][0]
    if op in ('cp', 'mv'):
        destination, kind = check_path(paths[-1], rules, shell)
        for value in paths[:-1]:
            source = normalize(value, rules)
            if op == 'mv':
                source, source_kind = check_path(source, rules, shell)
                check_tree(source, source_kind, shell)
            target = posixpath.join(destination, posixpath.basename(source)) if kind == 'DIR' else destination
            target, target_kind = check_path(target, rules, shell)
            check_tree(target, target_kind, shell)
    else:
        for value in paths:
            path, kind = check_path(value, rules, shell)
            if op in ('rm', 'rmdir'):
                check_tree(path, kind, shell)


def stop_targets(plan: dict[str, Any], shell: Callable[[str], Any]) -> list[str]:
    """STOP 目标核验：全量刷新应用清单 + UID 归属 + 保护系统/关键/自身/Shizuku。"""
    self_package = plan.get('selfPackage')
    if not isinstance(self_package, str) or not re.fullmatch(
            r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', self_package):
        raise Blocked('SELF_PACKAGE_UNVERIFIED')
    # 连接可能花时间；真正停止前在该连接上重新获取全量分组，不沿用旧快照。
    apps: list[dict[str, Any]] = []
    groups = ''
    for system in (False, True):
        output = checked(shell(argv_command(['pm', 'list', 'packages', '-U', '-s' if system else '-3'])))
        if len(output) > 1024 * 1024 or system and not output.strip():
            raise Blocked('应用清单不完整')
        groups += '[系统应用]\n' if system else '[用户应用]\n'
        for row in output.splitlines():
            if not row.strip():
                continue
            match = re.fullmatch(r'package:([A-Za-z0-9_.]+) uid:([0-9]+(?:,[0-9]+)*)', row.strip())
            if not match:
                raise Blocked('应用清单格式无法确认')
            apps.append(dict(name=match[1], uids={int(value) for value in match[2].split(',')}, system=system))
            groups += match[1] + ' uid=' + match[2] + '\n'
    if len({app['name'] for app in apps}) != len(apps):
        raise Blocked('应用归属冲突')
    plan['groups'] = groups
    by_name = {app['name']: app for app in apps}
    if self_package not in by_name:
        raise Blocked('SELF_PACKAGE_INVENTORY_MISSING')
    protected = {uid for app in apps if app['system'] or any(uid % 100000 < 10000 for uid in app['uids'])
                 or app['name'] in (self_package, 'moe.shizuku.privileged.api') for uid in app['uids']}
    requested = list(plan['operands'])
    if plan['argv'][0] == 'kill':
        rows = checked(shell(argv_command(['ps', '-A', '-o', 'PID,UID,NAME']))).splitlines()
        processes: dict[int, int] = {}
        for row in rows:
            columns = row.split(None, 2)
            if len(columns) != 3 or columns[0] == 'PID':
                continue
            if not columns[0].isdigit() or not columns[1].isdigit():
                raise Blocked('无法确认设备进程 UID')
            processes[int(columns[0])] = int(columns[1])
        requested = []
        for value in plan['operands']:
            uid = processes.get(int(value))
            if uid is None or uid % 100000 < 10000 or uid in protected:
                raise Blocked('系统关键进程或归属不明的 PID 不可结束：' + value)
            owners = [app['name'] for app in apps if uid in app['uids']]
            if len(owners) != 1:
                raise Blocked('PID 对应共享或未知 UID，请使用明确包名')
            requested.extend(owners)
    for name in requested:
        app = by_name.get(name)
        if not app or app['system'] or app['uids'] & protected:
            raise Blocked('系统、关键或未识别应用不可结束：' + name)
    return list(dict.fromkeys(requested))


def valid_vscreen_identity(value: Any) -> bool:
    """虚拟屏身份串：5 段（displayId:stableId:flags:uuid:uuid）严格核验。"""
    if not isinstance(value, str) or len(value) > 160:
        return False
    fields = value.split(':')
    if len(fields) != 5:
        return False
    uuid_re = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    return (bool(re.fullmatch(r'[1-9][0-9]{0,9}', fields[0])) and 1 < int(fields[0]) <= 2147483647
            and bool(re.fullmatch(r'[1-9][0-9]{0,18}', fields[1])) and int(fields[1]) <= 9223372036854775807
            and bool(re.fullmatch(r'0|[1-9][0-9]{0,9}', fields[2])) and int(fields[2]) <= 2147483647
            and bool(re.fullmatch(uuid_re, fields[3])) and bool(re.fullmatch(uuid_re, fields[4])))


def execute(plan: dict[str, Any], shell: Callable[[str], Any],
            result_class: Callable[[str, int], Any]) -> Any:
    """按 kind 分派执行；VIRTUAL_SCREEN / FILE 均一次发送、禁重放。"""
    if not isinstance(plan, dict) or plan.get('version') != 1 or plan.get('kind') not in ('READ', 'FILE', 'STOP', 'VIRTUAL_SCREEN'):
        raise Blocked('原生设备策略没有授权此操作')
    if plan['kind'] == 'VIRTUAL_SCREEN':
        argv = plan.get('argv')
        source = plan.get('sourceApk')
        self_package = plan.get('selfPackage')
        launch = isinstance(argv, list) and len(argv) == 9 and argv[4:7] == ['--launch', '--port', '0']
        probe = (isinstance(argv, list) and len(argv) == 9 and argv[4:6] == ['--probe-exit', '--identity']
                 and valid_vscreen_identity(argv[6]))
        if (not isinstance(argv, list) or len(argv) != 9 or argv[0] != 'app_process'
                or not isinstance(source, str) or not re.fullmatch(r'/data/app/[^\s]+\.apk', source)
                or '..' in source.split('/') or '\\' in source or '//' in source
                or argv[1] != '-Djava.class.path=' + source
                or argv[2] != '/system/bin'
                or argv[3] != 'com.deepseekharness.app.vscreen.VirtualScreenCore'
                or not (launch or probe)
                or not isinstance(self_package, str) or not re.fullmatch(
                    r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', self_package)
                or argv[7:] != ['--package', self_package]
                or plan.get('nativeAuthorization') != 'managed-vscreen-start'
                or not re.fullmatch(r'[a-f0-9]{48}', str(plan.get('nativeTicket', '')))
                or plan.get('su', False)):
            raise Blocked('虚拟屏启动参数无法核验')
        return shell(argv_command(argv))
    # ADB 自身可能有特权；短信文件路径绝不绕过原生查询授权。
    validate_root_reads(plan, shell)
    if plan['kind'] == 'STOP':
        # 在当前连接再次刷新清单，先验证全部目标，再按包名停止。
        targets = stop_targets(plan, shell)
        output = plan.get('groups', '')
        for name in targets:
            result = shell(argv_command(['am', 'force-stop', name]))
            output += '停止用户应用：' + name + '\n' + result.output + '\n'
            if result.exit_code != 0:
                return result_class(output, result.exit_code)
        return result_class(output, 0)
    if plan['kind'] == 'FILE':
        validate_files(plan, shell)
        argv = [normalize(value, plan['paths']) if value in plan['operands'] else value for value in plan['argv']]
        source, package, uid = plan.get('sourceApk'), plan.get('selfPackage'), plan.get('selfUid')
        if (not isinstance(source, str) or not re.fullmatch(r'/data/app/[^\s]+\.apk', source)
                or '..' in source.split('/') or '\\' in source or '//' in source
                or not isinstance(package, str) or not re.fullmatch(
                    r'[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+', package)
                or type(uid) is not int or uid < 10000
                or not isinstance(argv, list) or not argv
                or argv[0] not in ('mkdir', 'touch', 'cp', 'mv', 'rm', 'rmdir')):
            raise Blocked('FILE_EXECUTOR_IDENTITY_UNVERIFIED')
        # 一次发送，当前 APK 在特权进程内重新解析 FILE 计划并固定父目录描述符。
        # app_process/目录打开失败或结果未知均不得重放旧 cp/mv/rm。
        helper = ['app_process', '-Djava.class.path=' + source, '/system/bin',
                  'com.deepseekharness.app.DeviceFileCore', '--package', package, '--uid', str(uid), '--']
        return shell(argv_command(helper + argv))
    return shell(argv_command(plan['argv']))

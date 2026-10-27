#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# DSHA_ADB_SCRIPT_VERSION=20
# 版权来源：DSHA（MIT）app/src/main/assets/adb-shell.py —— 现代化重构，行为契约不变。
"""设备 shell：原生白名单判定、有限时连接、发送后不重放、真实远端退出码。

用法：shell.py [--host 本机IP] [--port 端口] [--timeout 秒] [--su] 命令
失败码：124=连接失败/超时，125=已发送但执行结果未知，126=策略拦截。
命令正常结束时，本地退出码与 [EXIT=n] 都使用远端退出码。

执行机器在 _adb_common（三态边界 run_on_endpoint / connect_with_retry）；
本文件负责 CLI 解析、桥执行路由（root/Shizuku 优先）与受管虚拟屏通道。
"""
from __future__ import annotations

# 非标准库 import 均为 rootfs 运行时解析（_adb_common / pip: adb_shell_wifi），
# 开发环境必然缺失——按设计抑制误报。
# pyright: reportMissingImports=false

import ipaddress
import json
import os
import re
import shlex
import sys
from typing import Any

from _adb_common import (
    COMMAND_TIMEOUT,
    CONNECT_TIMEOUT,
    KEY,
    KEYPUB,
    KEYDIR,
    ConnectFail,
    ExecutionUnknown,
    ShellResult,
    bridge_request,
    candidate_hosts,
    connect_with_retry,
    policy,
    vscreen_bridge_failure,
)


def vscreen_start_rejection(value: dict[str, Any] | Any) -> str:
    """把启动拒绝归一到固定代号（输出文本是宿主契约，不得改动）。"""
    output = value.get('output', '') if isinstance(value, dict) else ''
    if not isinstance(output, str):
        return 'ADB_START_BRIDGE_PLAN_REJECTED'
    if '虚拟屏启动许可无效、过期或已使用' in output:
        return 'ADB_START_BRIDGE_TICKET_REJECTED'
    if '无法核验 DSHA 安装包路径' in output:
        return 'ADB_START_BRIDGE_PATH_UNVERIFIED'
    if 'ADB 通道不可用' in output:
        return 'ADB_START_BRIDGE_CHANNEL_UNAVAILABLE'
    return 'ADB_START_BRIDGE_PLAN_REJECTED'


def request_native_vscreen_start(cmd: str, ticket: str) -> dict[str, Any]:
    """仅当原生管理器持有匹配启动租约时取受管启动计划。"""
    import urllib.request
    import urllib.parse
    try:
        with bridge_request('/device/vscreen/start', {'cmd': cmd, 'ticket': ticket}, timeout=15) as response:
            envelope = json.loads(response.read(1024 * 1024))
        if envelope.get('result') == '[UNAUTHORIZED]':
            raise policy.Blocked('ADB_START_BRIDGE_AUTH_REJECTED')
        value = json.loads(envelope['result'])
        plan = value.get('plan')
        if (value.get('state') != 'adb' or not isinstance(plan, dict)
                or plan.get('kind') != 'VIRTUAL_SCREEN' or plan.get('nativeTicket') != ticket
                or plan.get('nativeAuthorization') != 'managed-vscreen-start'):
            raise policy.Blocked(vscreen_start_rejection(value))
        return plan
    except policy.Blocked:
        raise
    except Exception as error:
        raise policy.Blocked(vscreen_bridge_failure('START', error)) from error


def request_native_execution(cmd: str, use_su: bool = False,
                             force_adb: bool = False) -> ShellResult | dict[str, Any]:
    """原生层先选 root/Shizuku；仅收到明确的 ADB 计划才连接，不重放未知结果。"""
    import urllib.request
    import urllib.parse
    try:
        with open('/root/.dsh/.bridge_token') as source:
            token = source.read().strip()
        if not token:
            raise ValueError('missing token')
    except (OSError, ValueError) as error:
        raise policy.Blocked('设备桥未准备好，请打开 DSHA 后重试') from error
    query = urllib.parse.urlencode(
        {'cmd': cmd, 'su': '1' if use_su else '0', 'adb': '1' if force_adb else '0'})
    request = urllib.request.Request(
        'http://127.0.0.1:3090/device/execute?' + query, headers={'X-Token': token})
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=155) as response:
            envelope = json.loads(response.read(1024 * 1024))
        value = json.loads(envelope['result'])
        if value.get('state') == 'completed':
            code = value.get('exit')
            if not isinstance(code, int) or not 0 <= code <= 255 or not isinstance(value.get('output'), str):
                raise ValueError('invalid execution result')
            return ShellResult(value['output'], code)
        plan = value.get('plan')
        if value.get('state') != 'adb' or not isinstance(plan, dict) or plan.get('version') != 1:
            raise ValueError('missing explicit ADB plan')
        if plan.get('kind') not in ('READ', 'FILE', 'STOP'):
            raise ValueError('invalid ADB plan')
        return plan
    except Exception as error:
        raise ExecutionUnknown('设备桥响应不完整，命令可能已执行，不会切换通道重试（'
                               + type(error).__name__ + '）') from error


def parse_args(args: list[str]) -> tuple[int, str, float, float, bool, bool, str]:
    """解析 CLI；返回 (port, host, timeout, connect_timeout, use_su, vscreen_launch, cmd)。"""
    port, host, timeout, connect_timeout, use_su, vscreen_launch = 0, '', COMMAND_TIMEOUT, CONNECT_TIMEOUT, False, False
    explicit_endpoint = False
    while args:
        option = args[0]
        if option == '--su':
            use_su = True
            args = args[1:]
        elif option == '--vscreen-launch':
            if vscreen_launch:
                raise ValueError('虚拟屏启动标记重复')
            vscreen_launch = True
            args = args[1:]
        elif option in ('--port', '--host', '--timeout', '--connect-timeout'):
            if len(args) < 2:
                raise ValueError(option + ' 缺少参数')
            value, args = args[1], args[2:]
            if option == '--host':
                host = str(ipaddress.ip_address(value))
                explicit_endpoint = True
            elif option == '--port':
                port = int(value)
                explicit_endpoint = True
                if not 1 <= port <= 65535:
                    raise ValueError('端口应在 1—65535')
            else:
                number = int(value)
                if not 1 <= number <= 180:
                    raise ValueError('超时应在 1—180 秒')
                if option == '--timeout':
                    timeout = number
                else:
                    connect_timeout = number
        elif option == '--':
            args = args[1:]
            break
        else:
            break
    if vscreen_launch and (use_su or explicit_endpoint):
        raise ValueError('受管虚拟屏启动不能覆盖设备通道或 Root 身份')
    return port, host, timeout, connect_timeout, use_su, vscreen_launch, \
        (args[0] if len(args) == 1 else shlex.join(args)) if args else 'id'


def read_vscreen_ticket(stream=None) -> str:
    """从私有父管道恰好读 48 字节一次性许可，随后要求 EOF。"""
    source = sys.stdin.buffer if stream is None else stream
    raw = source.read(49)
    if len(raw) != 48 or not re.fullmatch(rb'[a-f0-9]{48}', raw):
        raise ValueError('无效的受管虚拟屏启动许可')
    return raw.decode('ascii')


def main() -> int:
    try:
        port, host, timeout, connect_timeout, use_su, vscreen_launch, cmd = parse_args(sys.argv[1:])
        launch_ticket = read_vscreen_ticket() if vscreen_launch else ''
    except ValueError as e:
        print('INVALID_ARGUMENT: %s\n[EXIT=2]' % e)
        return 2
    try:
        plan = (request_native_vscreen_start(cmd, launch_ticket) if vscreen_launch
                else request_native_execution(cmd, use_su, bool(port or host)))
    except policy.Blocked as error:
        print('[POLICY_BLOCKED] %s\n[EXIT=126]' % error)
        return 126
    except ExecutionUnknown as error:
        print('EXECUTION_UNKNOWN: %s\n[EXIT=125]' % error)
        return 125
    if isinstance(plan, ShellResult):
        print(plan.output)
        return plan.exit_code
    if not (os.path.isfile(KEY) and os.path.isfile(KEYPUB)):
        print('NO_KEY: 请到设置 → 设备能力授权完成 ADB 无线配对\n[EXIT=1]')
        return 1
    try:
        from adb_shell_wifi.adb_device import AdbDeviceTls
        from adb_shell_wifi.auth.sign_pythonrsa import PythonRSASigner
    except ImportError:
        print('DEPS_MISSING: ADB 依赖未就绪，请重新打开配对页准备环境\n[EXIT=1]')
        return 1
    if not port:
        try:
            with open(KEYDIR + '/connect_port') as f:
                port = int(f.read(20).strip())
            if not 1 <= port <= 65535:
                port = 0
        except (OSError, ValueError):
            port = 0
    if not host:
        try:
            with open(KEYDIR + '/connect_host') as f:
                saved_host = f.read(128).strip()
            if saved_host in candidate_hosts():
                host = saved_host
        except OSError:
            pass
    try:
        result = connect_with_retry(AdbDeviceTls, PythonRSASigner, plan, port, host,
                                    connect_timeout, timeout)
    except policy.Blocked as error:
        print('[POLICY_BLOCKED] %s\n[EXIT=126]' % error)
        return 126
    except ConnectFail as e:
        print('CONNECT_FAIL: %s\n[EXIT=124]' % e)
        return 124
    except ExecutionUnknown as e:
        print('EXECUTION_UNKNOWN: %s\n[EXIT=125]' % e)
        return 125
    sys.stdout.write(result.output)
    if result.output and not result.output.endswith('\n'):
        print()
    print('[EXIT=%d]' % result.exit_code)
    return result.exit_code


if __name__ == '__main__':
    sys.exit(main())

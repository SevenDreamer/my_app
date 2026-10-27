#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 版权来源：DSHA（MIT）app/src/main/assets/adb-shell.py 的共享机器面 —— 现代化重构，行为契约不变。
"""ADB 共享机器面：密钥路径、限时连接、三态执行边界、mDNS 发现、桥客户端。

被 pair.py / shell.py 共用（替代原 DSHA 的 importlib.util 动态互载）。
三态契约（宿主解析的 API）：
  ConnectFail（124）      = 命令尚未发送，允许重新发现地址并重试；
  ExecutionUnknown（125）= 命令可能已执行，禁止自动重放；
  policy.Blocked（126）   = 策略拦截，根本没执行。
运行时 pip 依赖（rootfs 内）：adb_shell_wifi、zeroconf。
"""
from __future__ import annotations

# 非标准库 import 均为 rootfs 运行时解析（同目录 policy.py / pip 包），
# 开发环境必然缺失——按设计抑制误报。
# pyright: reportMissingImports=false

import ipaddress
import json
import os
import re
import shlex
import socket
import threading
import time
import uuid
from typing import Any, Callable

import policy

KEYDIR = '/root/.dsh/adbkeys'
KEY = KEYDIR + '/adbkey'
KEYPUB = KEY + '.pub'
TRANSPORT_TIMEOUT = 4.0
CONNECT_TIMEOUT = 25.0
COMMAND_TIMEOUT = 90.0


class ConnectFail(Exception):
    """命令尚未发送，允许重新发现地址。"""


class ExecutionUnknown(Exception):
    """命令可能已执行，禁止自动重放。"""


class ShellResult:
    """远端命令结果：output 为剥离退出码标记后的输出。"""

    def __init__(self, output: str, exit_code: int) -> None:
        self.output = output
        self.exit_code = exit_code


def atomic_text(path: str, text: str) -> None:
    """写临时文件后原子替换。"""
    tmp = path + '.' + uuid.uuid4().hex + '.tmp'
    try:
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write(text)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def local_ips() -> list[str]:
    """只枚举本机接口，不向公网地址探路。"""
    found = []
    try:
        import subprocess
        rows = json.loads(subprocess.check_output(
            ['ip', '-j', '-4', 'address', 'show'], timeout=3,
            stderr=subprocess.DEVNULL).decode())
        found = [a['local'] for r in rows for a in r.get('addr_info', [])
                 if a.get('family') == 'inet']
    except Exception:
        try:
            import fcntl
            import struct
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
                for _, name in socket.if_nameindex():
                    try:
                        # fcntl.ioctl 仅 Linux 有；rootfs 内真实存在，Windows 开发环境是误报。
                        data = fcntl.ioctl(sock.fileno(), 0x8915,  # pyright: ignore[reportAttributeAccessIssue]
                            struct.pack('256s', name.encode()[:15]))
                        found.append(socket.inet_ntoa(data[20:24]))
                    except OSError:
                        pass
        except Exception:
            pass
    return list(dict.fromkeys(a for a in found if a and not a.startswith('127.')))


def candidate_hosts(preferred: str = '') -> list[str]:
    """本机地址候选：显式指定优先，127.0.0.1 兜底。"""
    hosts = local_ips()
    if preferred:
        ipaddress.ip_address(preferred)
        hosts.insert(0, preferred)
    hosts.append('127.0.0.1')
    return list(dict.fromkeys(hosts))


def discover_endpoints(service_type: str, timeout_s: float = 4,
                       allowed_hosts: list[str] | None = None) -> list[tuple[str, int]]:
    """mDNS 发现（zeroconf，惰性导入）。保留主机/端口关联，只接受本机；
    所有退出路径都停止 mDNS。"""
    allowed = set(candidate_hosts() if allowed_hosts is None else allowed_hosts)
    found: dict[str, list[tuple[str, int]]] = {}
    lock = threading.Lock()
    zc = browser = None
    until = time.monotonic() + timeout_s
    try:
        from zeroconf import Zeroconf, ServiceBrowser, ServiceListener
        class Listener(ServiceListener):
            def add_service(self, client, type_, name):
                remaining = until - time.monotonic()
                if remaining <= 0:
                    return
                info = client.get_service_info(type_, name, timeout=max(1, int(min(remaining, 1) * 1000)))
                if info is None or not 1 <= info.port <= 65535:
                    return
                addresses = [a for a in info.parsed_addresses() if a in allowed]
                if addresses:
                    with lock:
                        found[name] = [(a, info.port) for a in addresses]
            def update_service(self, client, type_, name):
                self.remove_service(client, type_, name)
                self.add_service(client, type_, name)
            def remove_service(self, client, type_, name):
                with lock:
                    found.pop(name, None)
        zc = Zeroconf()
        browser = ServiceBrowser(zc, service_type, Listener())
        time.sleep(max(0, until - time.monotonic()))
        with lock:
            return list(dict.fromkeys(ep for name in sorted(found) for ep in found[name]))
    except Exception:
        return []
    finally:
        if browser is not None:
            try:
                browser.cancel()
            except Exception:
                pass
        if zc is not None:
            try:
                zc.close()
            except Exception:
                pass


def load_port_history() -> list[int]:
    """最近验证过的端口（最多 5 个）。"""
    try:
        with open(KEYDIR + '/connect_port_history') as f:
            values = f.read(1024).split()
        return list(dict.fromkeys(int(v) for v in values if v.isdigit() and 1 <= int(v) <= 65535))[:5]
    except Exception:
        return []


def remember_endpoint(host: str, port: int) -> None:
    """只有握手/命令已验证的地址才写入，发现失败不能污染可用端口。"""
    try:
        atomic_text(KEYDIR + '/connect_host', host)
        atomic_text(KEYDIR + '/connect_port', str(port))
        history = [port] + [p for p in load_port_history() if p != port]
        atomic_text(KEYDIR + '/connect_port_history', '\n'.join(map(str, history[:5])) + '\n')
    except OSError:
        pass


def frame_command(cmd: str, marker: str) -> str:
    """子 shell 隔离 exit/exec；随机尾部标记避免普通输出碰撞。"""
    return '/system/bin/sh -c ' + shlex.quote(cmd) + "; __dsha_rc=$?; printf '\\n" + marker + "%s\\n' \"$__dsha_rc\""


def parse_shell_result(raw: bytes | str, marker: str) -> ShellResult:
    """解析带退出码标记的输出；标记缺失 = 结果未知（125 语义）。"""
    out = raw.decode('utf-8', 'replace') if isinstance(raw, bytes) else str(raw)
    match = re.search(r'\r?\n' + re.escape(marker) + r'([0-9]{1,3})\r?\n?\Z', out)
    if match is None or int(match.group(1)) > 255:
        raise ExecutionUnknown('未收到完整退出码；命令可能已执行，不会自动重试')
    return ShellResult(out[:match.start()], int(match.group(1)))


def bridge_request(route: str, parameters: dict[str, str], timeout: float):
    """宿主鉴权桥（127.0.0.1:3090，X-Token）。"""
    import urllib.request
    import urllib.parse
    with open('/root/.dsh/.bridge_token') as source:
        token = source.read().strip()
    if not token:
        raise ValueError('CREDENTIAL_UNAVAILABLE')
    request = urllib.request.Request(
        'http://127.0.0.1:3090' + route + '?' + urllib.parse.urlencode(parameters),
        headers={'X-Token': token})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    return opener.open(request, timeout=timeout)


def vscreen_bridge_failure(stage: str, error: Exception) -> str:
    """固定 stage/reason 组合：异常原文可能含凭据或私有路径，不得外泄。"""
    import urllib.error
    if isinstance(error, urllib.error.HTTPError):
        reason = 'HTTP_ERROR'
    elif isinstance(error, (TimeoutError, socket.timeout)):
        reason = 'TIMEOUT'
    elif isinstance(error, urllib.error.URLError):
        reason = 'TIMEOUT' if isinstance(error.reason, (TimeoutError, socket.timeout)) else 'CONNECT_FAILED'
    elif isinstance(error, (FileNotFoundError, PermissionError)):
        reason = 'CREDENTIAL_UNAVAILABLE'
    elif isinstance(error, (ValueError, KeyError, TypeError)):
        reason = 'INVALID_RESPONSE'
    else:
        reason = 'FAILED'
    return 'ADB_' + stage + '_BRIDGE_' + reason


def request_device_plan(cmd: str, use_su: bool = False) -> dict[str, Any]:
    """所有设备命令均经过同一原生白名单；不接受 DSH_INTERNAL 或关闭确认来绕过。"""
    import urllib.request
    import urllib.parse
    try:
        with open('/root/.dsh/.bridge_token') as source:
            token = source.read().strip()
        if not token:
            raise ValueError('missing token')
        query = urllib.parse.urlencode({'cmd': cmd, 'su': '1' if use_su else '0'})
        request = urllib.request.Request('http://127.0.0.1:3090/device/plan?' + query, headers={'X-Token': token})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=75) as response:
            value = json.loads(response.read(1024 * 1024)).get('result')
        if not isinstance(value, str) or not value.startswith('{'):
            raise policy.Blocked(str(value or '原生策略未就绪'))
        plan = json.loads(value)
        if plan.get('version') != 1 or plan.get('kind') not in ('READ', 'FILE', 'STOP'):
            raise policy.Blocked(plan.get('reason') or '命令未获策略允许')
        plan['su'] = use_su
        return plan
    except policy.Blocked:
        raise
    except Exception as error:
        raise policy.Blocked('设备策略桥不可用，命令未发送；请打开或更新 DSHA（' + type(error).__name__ + '）') from error


def request_native_vscreen_commit(ticket: str) -> None:
    """在 ADB 发送前一刻消费一次性虚拟屏启动许可。"""
    import urllib.request
    import urllib.parse
    try:
        with bridge_request('/device/vscreen/commit', {'ticket': ticket}, timeout=10) as response:
            value = json.loads(response.read(65536)).get('result')
        if value != 'VSCREEN_START_COMMITTED':
            raise policy.Blocked('ADB_COMMIT_BRIDGE_AUTH_REJECTED' if value == '[UNAUTHORIZED]' else 'ADB_COMMIT_BRIDGE_TICKET_REJECTED')
    except policy.Blocked:
        raise
    except Exception as error:
        # 丢失的 commit 响应可能意味着一次性许可已被消费——绝不发送、绝不重试。
        raise ExecutionUnknown(vscreen_bridge_failure('COMMIT', error)) from error


def run_on_endpoint(device_cls: type, signer_cls: type, cmd: Any,
                    host: str, port: int, deadline: float,
                    command_timeout: float = COMMAND_TIMEOUT) -> ShellResult:
    """三态执行边界：连接阶段异常=124 可重试；命令进入发送即 125 禁重放。"""
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise ConnectFail('连接总时限已到，命令尚未发送')
    dev = None
    try:
        try:
            with open(KEYPUB, 'rb') as f:
                public = f.read().strip()
            with open(KEY, 'rb') as f:
                private = f.read()
            signer = signer_cls(public, private)
            dev = device_cls(host, port, default_transport_timeout_s=min(TRANSPORT_TIMEOUT, remaining))
            connected = dev.connect(rsa_keys=[signer], transport_timeout_s=min(TRANSPORT_TIMEOUT, remaining),
                auth_timeout_s=min(8, remaining), read_timeout_s=min(8, remaining), tls_priv_pem=private)
            if not connected:
                raise ConnectionError('ADB 握手未完成')
            if time.monotonic() >= deadline:
                raise TimeoutError('连接总时限已到')
        except Exception as e:
            raise ConnectFail('%s:%d %s: %s' % (host, port, type(e).__name__, str(e)[:200])) from e
        # 从这里开始即使异常也禁止换地址重放，包括不兼容库抛出的 TypeError。
        try:
            def shell(command: str) -> ShellResult:
                marker = '__DSHA_EXIT_' + uuid.uuid4().hex + '__='
                if isinstance(cmd, dict) and cmd.get('capability') == 'sms.read':
                    # 连接可能比用户的原生授权活得久：发送前最后一刻用同一规范查询
                    # 复核授权；新计划不得悄悄改变用户或请求字段。
                    current = request_device_plan(command, bool(cmd.get('su')))
                    if (current.get('authorization') != 'remembered'
                            or any(current.get(key) != cmd.get(key)
                                   for key in ('version', 'kind', 'argv', 'capability', 'authorization'))):
                        raise policy.Blocked('敏感查询授权或内容已变化，命令未发送')
                if isinstance(cmd, dict) and cmd.get('kind') == 'VIRTUAL_SCREEN':
                    if cmd.get('_dsha_sent'):
                        raise policy.Blocked('受管虚拟屏启动只允许发送一次')
                    ticket = cmd.get('nativeTicket', '')
                    if not re.fullmatch(r'[a-f0-9]{48}', ticket):
                        raise policy.Blocked('缺少受管虚拟屏启动许可')
                    request_native_vscreen_commit(ticket)
                    cmd['_dsha_sent'] = True
                if isinstance(cmd, dict) and cmd.get('su'):
                    command = 'su -c ' + shlex.quote(command)
                raw = dev.shell(frame_command(command, marker),
                    transport_timeout_s=min(TRANSPORT_TIMEOUT, command_timeout),
                    read_timeout_s=min(8, command_timeout), timeout_s=command_timeout)
                return parse_shell_result(raw, marker)
            result = policy.execute(cmd, shell, ShellResult) if isinstance(cmd, dict) else shell(cmd)
        except policy.Blocked:
            raise
        except Exception as e:
            raise ExecutionUnknown('%s:%d 返回中断（%s）；命令可能已执行，请先检查设备，未自动重试'
                                   % (host, port, type(e).__name__)) from e
        remember_endpoint(host, port)
        return result
    finally:
        if dev is not None:
            try:
                dev.close()
            except Exception:
                pass


def connect_with_retry(device_cls: type, signer_cls: type, cmd: Any,
                       port: int, host: str = '',
                       connect_timeout: float = CONNECT_TIMEOUT,
                       command_timeout: float = COMMAND_TIMEOUT) -> ShellResult:
    """地址发现顺序：显式端口 → mDNS → 端口历史+5555；只在 124 时换地址。"""
    deadline = time.monotonic() + connect_timeout
    hosts = candidate_hosts(host)
    tried: set[tuple[str, int]] = set()
    errors: list[str] = []

    def attempt(endpoints: list[tuple[str, int]]) -> ShellResult | None:
        for addr, p in endpoints:
            if (addr, p) in tried or not 1 <= p <= 65535 or time.monotonic() >= deadline:
                continue
            tried.add((addr, p))
            try:
                return run_on_endpoint(device_cls, signer_cls, cmd, addr, p, deadline, command_timeout)
            except ConnectFail as e:
                errors.append(str(e))
        return None

    result = attempt([(h, port) for h in hosts] if port else [])
    if result is not None:
        return result
    remaining = deadline - time.monotonic()
    if remaining > 0:
        result = attempt(discover_endpoints('_adb-tls-connect._tcp.local.', min(4, remaining), hosts))
        if result is not None:
            return result
    result = attempt([(h, p) for p in load_port_history() + [5555] for h in hosts])
    if result is not None:
        return result
    raise ConnectFail('命令尚未发送；请检查无线调试与配对授权。尝试记录：\n' + '\n'.join(errors[-8:]))

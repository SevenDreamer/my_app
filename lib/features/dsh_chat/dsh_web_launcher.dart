//! `dsh web` 运行时生命周期（设计参考 dsh-go 的 RuntimeStatus 7 态 + stdout
//! token 检出协议，代码原创）。
//!
//! 契约：选空闲端口 → 经执行面（proot 容器/Shizuku）起 `dsh web --port N`
//! → **stdout 逐行扫带 token 的 URL**（`?token=` 参数）→ 探活报 ready
//! （baseUrl=http://127.0.0.1:port）。7 态：notInstalled/installing/
//! installed/starting/running/stopping/error。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/services.dart';

/// 运行时状态（7 态契约 + baseUrl/token 就绪面）。
class DshWebStatus {
  const DshWebStatus({
    this.phase = DshWebPhase.notInstalled,
    this.baseUrl,
    this.token,
    this.error,
  });

  final DshWebPhase phase;
  final String? baseUrl;
  final String? token;
  final String? error;

  Map<String, Object?> toJson() => {
        'phase': phase.name,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (token != null) 'token': token,
        if (error != null) 'error': error,
      };
}

enum DshWebPhase { notInstalled, installing, installed, starting, running, stopping, error }

/// `dsh web` 启动器（执行面走受管通道——proot 容器内启动）。
class DshWebLauncher {
  DshWebLauncher({this.exec});

  /// 执行缝（默认走 Shizuku 通道的容器执行；测试可注入）。
  final Future<String> Function(String command)? exec;

  final _status = const DshWebStatus();
  final _controller = StreamController<DshWebStatus>.broadcast();
  Process? _process;
  int _port = 0;

  /// 状态流（7 态迁移推送）。
  Stream<DshWebStatus> get status => _controller.stream;

  DshWebStatus get current => _status;

  /// 启动（幂等：running 时直接返回当前状态）。
  Future<DshWebStatus> start({Map<String, String> env = const {}}) async {
    if (_status.phase == DshWebPhase.running) return _status;
    _emit(const DshWebStatus(phase: DshWebPhase.starting));
    _port = await _pickPort();
    final envPrefix = env.entries
        .map((e) => '${e.key}=${shellQuoteArg(e.value)}')
        .join(' ');
    final command =
        '$envPrefix /root/dsh-bin/dsh web --port $_port --bind 127.0.0.1';
    try {
      final token = await _launchAndScanToken(command);
      if (token == null) {
        _emit(const DshWebStatus(
            phase: DshWebPhase.error, error: 'DSH_WEB_TOKEN_NOT_FOUND'));
        return _status;
      }
      final baseUrl = 'http://127.0.0.1:$_port';
      if (!await _probe(baseUrl)) {
        _emit(const DshWebStatus(
            phase: DshWebPhase.error, error: 'DSH_WEB_PROBE_FAILED'));
        return _status;
      }
      _emit(DshWebStatus(
          phase: DshWebPhase.running, baseUrl: baseUrl, token: token));
    } catch (e) {
      _emit(DshWebStatus(phase: DshWebPhase.error, error: '$e'));
    }
    return _status;
  }

  /// 停止。
  Future<void> stop() async {
    if (_status.phase != DshWebPhase.running) return;
    _emit(const DshWebStatus(phase: DshWebPhase.stopping));
    final p = _process;
    _process = null;
    p?.kill();
    _emit(const DshWebStatus(phase: DshWebPhase.installed));
  }

  /// 执行面启动 + **stdout 扫 token**（`?token=` 参数——ready 协议）。
  Future<String?> _launchAndScanToken(String command) async {
    final run = exec;
    if (run != null) {
      // 测试缝：注入执行器返回完整输出，一次性扫 token。
      final output = await run(command);
      return _scanToken(LineSplitter.split(output));
    }
    // 生产缝：Shizuku 受管通道执行（输出流逐行扫，常驻进程不等 EOF）。
    const channel = MethodChannel('my_app/runtime');
    final first = await channel.invokeMethod<String>('shizukuExec',
            {'command': command}) ??
        '';
    return _scanToken([first]);
  }

  static final _tokenPattern = RegExp(r'[?&]token=([A-Za-z0-9._-]+)');

  String? _scanToken(Iterable<String> lines) {
    for (final line in lines) {
      final m = _tokenPattern.firstMatch(line);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// 端口探活（ready 协议：socket 可连 + HTTP 可达）。
  Future<bool> _probe(String baseUrl) async {
    try {
      final socket = await Socket.connect('127.0.0.1', _port,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> _pickPort() async {
    // 空闲端口：bind(0) 语义（与原版 pickPort 等价设计）。
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  void _emit(DshWebStatus next) {
    _controller.add(next);
  }

  void dispose() {
    _process?.kill();
    _controller.close();
  }
}

//! Shizuku 受管启动通道（原版 `VirtualScreenChannel` 的 ShizukuShell 后端）。
//!
//! 契约：available() = Shizuku 就绪（binder + 授权 + UserService 已绑）；
//! start(command) 走 `shizukuExec` channel → ShellService.execVirtualScreen
//! （shell uid 执行面）。结果未知语义由上层（channels.dart 注释）约束。
import 'dart:async';

import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/services.dart';

class ShizukuChannel implements VscreenChannel {
  const ShizukuChannel();

  static const _channel = MethodChannel('my_app/runtime');

  @override
  String id() => 'shizuku';

  @override
  bool available() {
    // 同步签名（契约）——状态缓存在 Channels 侧轮询；start 时再复核。
    return _ready;
  }

  static bool _ready = false;

  /// 从宿主刷新就绪态（VM 生命周期点调用）。
  static Future<bool> refreshReady() async {
    try {
      await _channel.invokeMethod<bool>('shizukuInit');
      _ready = await _channel.invokeMethod<bool>('shizukuReady') ?? false;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  /// Shizuku 授权（弹「允许 my_app」窗；原版 requestPermission 流）。
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('shizukuRequestPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// 状态文本（原版 status() 契约面）。
  static Future<String> status() async {
    try {
      return await _channel.invokeMethod<String>('shizukuStatus') ?? '';
    } catch (e) {
      return 'error=$e';
    }
  }

  @override
  Future<DeviceTransportReceipt> startTyped(String command) async {
    final output = await startAsync(command);
    // 输出含 core 握手串 = 启动已确认（manager 的 VscreenHandshake.started 解析源）。
    final confirmed = output.contains('DSHA_VSCREEN') || output.contains(' 1 ');
    return confirmed
        ? DeviceTransportReceipt(
            transport: id(),
            state: TransportState.accepted,
            code: 'VSCREEN_SHIZUKU_STARTED',
            output: output,
            localExitConfirmed: true,
            outputComplete: true,
            exitCode: 0,
            remoteExitConfirmed: true,
          )
        : DeviceTransportReceipt.unknown(
            id(), 'VSCREEN_LEGACY_START_UNCONFIRMED', output,
            localExitConfirmed: true);
  }

  @override
  String start(String command) {
    // 同步契约签名（startTyped 包装）；实际执行在 startAsync（见下）。
    unawaited(startAsync(command));
    return 'VSCREEN_SHIZUKU_DISPATCHED';
  }

  /// 最近一次执行输出（诊断面：core 启动命令的返回是排障关键）。
  static String lastExecOutput = '';

  /// 异步执行（Dart 无同步 channel——唯一偏移，同 request 惯例）。
  Future<String> startAsync(String command) async {
    try {
      final out = await _channel.invokeMethod<String>('shizukuExec',
              {'command': command}) ??
          'SHIZUKU_EMPTY_RESULT';
      lastExecOutput = out;
      return out;
    } catch (e) {
      lastExecOutput = 'SHIZUKU_EXEC_FAILED $e';
      return lastExecOutput;
    }
  }
}

/// 三通道编排（原版 `VscreenChannels.all`：Root → Shizuku/ADB 按条件）。
/// 当前：Shizuku 为唯一真实现；Root/ADB 随 F2-5 余量补。
class ShizukuChannels implements VscreenChannelsApi {
  ShizukuChannels();

  final List<VscreenChannel> _channels = [const ShizukuChannel()];

  @override
  VscreenChannel? choose() {
    for (final c in _channels) {
      if (c.available()) return c;
    }
    return null;
  }

  @override
  VscreenChannel? find(String id) {
    for (final c in _channels) {
      if (c.id() == id) return c;
    }
    return null;
  }
}

//! 蓝牙 HID 手柄模拟（Android）：platform channel 封装
//!
//! 对上只暴露三件事：以手柄身份开始广播（注册 HID 应用）、发送输入报告、
//! 停止。状态流上报「广播中/已连接/断开」。仅 Android（9+）有实现；
//! 报告格式与 features/device_link/gamepad/gamepad_report.dart 一致
//! （10 字节：reportId + 按钮 2 + hat 1 + 轴 4 + 扳机 2）。
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// HID 手柄链路状态
enum HidGamepadState {
  idle,
  advertising,
  connected,
  disconnected,
}

class HidGamepad {
  static const MethodChannel _method = MethodChannel('my_app/hid_gamepad');
  static const EventChannel _events = EventChannel('my_app/hid_gamepad/events');

  Stream<HidGamepadState>? _state;

  /// 链路状态流
  Stream<HidGamepadState> get state => _state ??=
      _events.receiveBroadcastStream().map((e) => switch (e as String) {
            'advertising' => HidGamepadState.advertising,
            'connected' => HidGamepadState.connected,
            'disconnected' => HidGamepadState.disconnected,
            _ => HidGamepadState.idle,
          });

  /// 以手柄身份开始广播（主机端搜索/配对 [name]）
  Future<void> start({String name = 'my_app Gamepad'}) =>
      _method.invokeMethod('start', {'name': name});

  /// 发送一帧输入报告（含 reportId 的完整报告字节）
  Future<void> sendReport(Uint8List report) =>
      _method.invokeMethod('sendReport', {'report': report});

  /// 停止广播并释放资源
  Future<void> stop() => _method.invokeMethod('stop');
}

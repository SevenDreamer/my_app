//! 假手柄链路：M0 调试用——不走真实蓝牙，把报告字节打进调试日志
//!
//! M1 接入 packages/hid_gamepad 后，由 HidGamepadLink 取代。
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gamepad_link.dart';
import 'gamepad_report.dart';

class FakeGamepadLink implements GamepadLink {
  final _controller = StreamController<GamepadLinkState>.broadcast();
  int _sent = 0;

  @override
  Stream<GamepadLinkState> get state => _controller.stream;

  @override
  Future<void> startAsGamepad({String name = 'my_app Gamepad'}) async {
    _controller.add(GamepadLinkState.advertising);
    // 假链路：无真实主机，立即视为已连接
    _controller.add(GamepadLinkState.connected);
  }

  @override
  Future<void> sendInputReport(GamepadReport report) async {
    _sent++;
    final hex = report
        .encode()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    debugPrint('[FakeGamepadLink] #$_sent $hex');
  }

  @override
  Future<void> stop() async {
    _controller.add(GamepadLinkState.idle);
    await _controller.close();
  }
}

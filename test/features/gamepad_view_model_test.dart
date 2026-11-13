//! GamepadViewModel 单测（测试安全网扩面，2026-11-13）。
//!
//! 假 GamepadLink 驱动：连接/停止/按键编排——report 流转与帧计数。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/gamepad/gamepad_link.dart';
import 'package:my_app/features/gamepad/gamepad_report.dart';
import 'package:my_app/features/gamepad/gamepad_view_model.dart';

class FakeLink implements GamepadLink {
  final _state = StreamController<GamepadLinkState>.broadcast();
  final List<String> calls = [];
  final List<GamepadReport> sent = [];

  @override
  Stream<GamepadLinkState> get state => _state.stream;

  @override
  Future<void> startAsGamepad({String name = 'my_app Gamepad'}) async {
    calls.add('start:$name');
    _state.add(GamepadLinkState.connected);
  }

  @override
  Future<void> sendInputReport(GamepadReport report) async {
    calls.add('send');
    sent.add(report);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _state.add(GamepadLinkState.idle);
  }
}

void main() {
  setUp(() {
    // flutter test 默认 TargetPlatform.android——会让 connect 先走蓝牙权限
    // 请求（测试环境 MissingPluginException 被 catch，链路启动到不了）
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('connect：链路启动 + 状态到位', () async {
    final link = FakeLink();
    final vm = GamepadViewModel(link);
    await vm.connect();
    expect(link.calls.first, startsWith('start:'));
    expect(link.calls, contains('send')); // 连接后发初始报告
    vm.dispose();
  });

  test('setButton：按键入报告 + 帧计数增长', () async {
    final link = FakeLink();
    final vm = GamepadViewModel(link);
    await vm.connect();
    final framesBefore = vm.frames;
    vm.setButton(0x0001, true);
    expect(link.sent.last.buttons & 0x0001, 0x0001);
    expect(vm.frames, greaterThan(framesBefore));
    vm.setButton(0x0001, false);
    expect(link.sent.last.buttons & 0x0001, 0);
    vm.dispose();
  });

  test('stop：链路停止', () async {
    final link = FakeLink();
    final vm = GamepadViewModel(link);
    await vm.connect();
    await vm.stop();
    expect(link.calls, contains('stop'));
    vm.dispose();
  });
}

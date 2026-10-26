//! HID 手柄链路：GamepadLink 的 Android 实现（packages/hid_gamepad 平台通道）
import 'package:hid_gamepad/hid_gamepad.dart';

import 'gamepad_link.dart';
import 'gamepad_report.dart';

class HidGamepadLink implements GamepadLink {
  final _gamepad = HidGamepad();

  @override
  Stream<GamepadLinkState> get state => _gamepad.state.map((s) => switch (s) {
        HidGamepadState.advertising => GamepadLinkState.advertising,
        HidGamepadState.connected => GamepadLinkState.connected,
        HidGamepadState.disconnected => GamepadLinkState.disconnected,
        HidGamepadState.idle => GamepadLinkState.idle,
      });

  @override
  Future<void> startAsGamepad({String name = 'my_app Gamepad'}) =>
      _gamepad.start(name: name);

  @override
  Future<void> sendInputReport(GamepadReport report) =>
      _gamepad.sendReport(report.encode());

  @override
  Future<void> stop() => _gamepad.stop();
}

//! 手柄输入报告：HID 输入报告的 Dart 表示与编解码
//!
//! 报告格式与 packages/hid_gamepad 的 HID 描述符一一对应（10 字节）：
//! [0] reportId(0x01) · [1-2] 按钮位图（小端）· [3] 十字键 hat ·
//! [4-7] LX/LY/RX/RY · [8-9] L2/R2 扳机。
//! 格式改动 = HID 描述符改动 = 主机端重新识别，故以单测钉死。
import 'dart:typed_data';

import '../../core/ffi/rust_core_stub.dart'
    if (dart.library.io) '../../core/ffi/rust_core.dart';

/// 按钮位（[GamepadReport.buttons] 位图中的 bit）
abstract class GamepadButton {
  static const int a = 1 << 0;
  static const int b = 1 << 1;
  static const int x = 1 << 2;
  static const int y = 1 << 3;
  static const int l1 = 1 << 4;
  static const int r1 = 1 << 5;
  static const int back = 1 << 6;
  static const int start = 1 << 7;
  static const int l3 = 1 << 8;
  static const int r3 = 1 << 9;

  /// 全部按钮位的并集（10 位）
  static const int all = (1 << 10) - 1;
}

/// 十字键（HID hat switch）：0-7 顺时针（0=上、2=右、4=下、6=左），8=居中
abstract class GamepadDpad {
  static const int up = 0;
  static const int upRight = 1;
  static const int right = 2;
  static const int downRight = 3;
  static const int down = 4;
  static const int downLeft = 5;
  static const int left = 6;
  static const int upLeft = 7;
  static const int centered = 8;
}

/// 一帧手柄输入
class GamepadReport {
  const GamepadReport({
    this.buttons = 0,
    this.dpad = GamepadDpad.centered,
    this.lx = _center,
    this.ly = _center,
    this.rx = _center,
    this.ry = _center,
    this.l2 = 0,
    this.r2 = 0,
  });

  static const int _center = 128;

  /// 报告标识（固定 0x01）
  static const int reportId = 0x01;

  /// 报告字节长度
  static const int byteLength = 10;

  /// 按钮位图（[GamepadButton] 常量的按位或）
  final int buttons;

  /// 十字键（[GamepadDpad] 常量）
  final int dpad;

  /// 左摇杆 X/Y：0-255，128 居中
  final int lx;
  final int ly;

  /// 右摇杆 X/Y：0-255，128 居中
  final int rx;
  final int ry;

  /// L2/R2 扳机行程：0-255
  final int l2;
  final int r2;

  /// [mask] 按钮是否按下
  bool pressed(int mask) => buttons & mask != 0;

  /// 编码为 HID 输入报告字节
  /// 编码（Dart→Rust 迁移第一批 B）：Rust core_gamepad_encode 打头（60fps
  /// 发送侧性能点），原 Dart 实现兜底（Rust 不可用时——增强件降级原则）。
  Uint8List encode() {
    final rust = RustCore.ensureLoaded()?.gamepadEncode(
      reportId: reportId,
      buttons: buttons,
      dpad: dpad,
      lx: lx,
      ly: ly,
      rx: rx,
      ry: ry,
      l2: l2,
      r2: r2,
    );
    if (rust != null) return Uint8List.fromList(rust);
    return _encodeDart();
  }

  Uint8List _encodeDart() {
    _checkRange(buttons, 0, 0xFFFF, 'buttons');
    _checkRange(dpad, 0, 8, 'dpad');
    for (final (name, v) in [
      ('lx', lx),
      ('ly', ly),
      ('rx', rx),
      ('ry', ry),
      ('l2', l2),
      ('r2', r2),
    ]) {
      _checkRange(v, 0, 255, name);
    }
    return Uint8List.fromList([
      reportId,
      buttons & 0xFF,
      (buttons >> 8) & 0xFF,
      dpad,
      lx,
      ly,
      rx,
      ry,
      l2,
      r2,
    ]);
  }

  /// 从 HID 输入报告字节解码；长度或 reportId 不符抛 [FormatException]
  static GamepadReport decode(Uint8List bytes) {
    if (bytes.length != byteLength) {
      throw FormatException('报告长度应为 $byteLength，实际 ${bytes.length}');
    }
    if (bytes[0] != reportId) {
      throw FormatException('reportId 应为 $reportId，实际 ${bytes[0]}');
    }
    return GamepadReport(
      buttons: bytes[1] | (bytes[2] << 8),
      dpad: bytes[3],
      lx: bytes[4],
      ly: bytes[5],
      rx: bytes[6],
      ry: bytes[7],
      l2: bytes[8],
      r2: bytes[9],
    );
  }

  static void _checkRange(int v, int min, int max, String name) {
    if (v < min || v > max) {
      throw RangeError.range(v, min, max, name);
    }
  }
}

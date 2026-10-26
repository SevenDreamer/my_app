//! GamepadReport 编解码单测：HID 报告格式的“协议合同”
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/gamepad/gamepad_report.dart';

void main() {
  group('GamepadReport.encode', () {
    test('默认报告（全居中/无按键）的黄金字节', () {
      expect(
        const GamepadReport().encode(),
        equals(Uint8List.fromList([0x01, 0x00, 0x00, 0x08, 128, 128, 128, 128, 0, 0])),
      );
    });

    test('按钮位图按小端写入 [1-2]', () {
      final bytes = const GamepadReport(
        buttons: GamepadButton.a | GamepadButton.r3,
      ).encode();
      expect(bytes[1], 0x01); // bit0 = A
      expect(bytes[2], 0x02); // bit9 = R3 → 高字节 bit1
    });

    test('越界值抛 RangeError', () {
      expect(() => const GamepadReport(dpad: 9).encode(), throwsRangeError);
      expect(() => const GamepadReport(lx: 256).encode(), throwsRangeError);
      expect(() => const GamepadReport(buttons: 0x10000).encode(), throwsRangeError);
    });
  });

  group('GamepadReport.decode', () {
    test('编码→解码往返一致', () {
      const r = GamepadReport(
        buttons: GamepadButton.x | GamepadButton.l1 | GamepadButton.start,
        dpad: GamepadDpad.downLeft,
        lx: 10,
        ly: 250,
        rx: 128,
        ry: 0,
        l2: 77,
        r2: 255,
      );
      final d = GamepadReport.decode(r.encode());
      expect(d.buttons, r.buttons);
      expect(d.dpad, r.dpad);
      expect(d.lx, r.lx);
      expect(d.ly, r.ly);
      expect(d.rx, r.rx);
      expect(d.ry, r.ry);
      expect(d.l2, r.l2);
      expect(d.r2, r.r2);
    });

    test('长度不符抛 FormatException', () {
      expect(
        () => GamepadReport.decode(Uint8List.fromList([0x01, 0, 0])),
        throwsFormatException,
      );
    });

    test('reportId 不符抛 FormatException', () {
      final bytes = const GamepadReport().encode()..[0] = 0x02;
      expect(() => GamepadReport.decode(bytes), throwsFormatException);
    });
  });

  group('GamepadReport.pressed', () {
    test('按位判断', () {
      const r = GamepadReport(buttons: GamepadButton.b | GamepadButton.r1);
      expect(r.pressed(GamepadButton.b), isTrue);
      expect(r.pressed(GamepadButton.r1), isTrue);
      expect(r.pressed(GamepadButton.a), isFalse);
    });
  });
}

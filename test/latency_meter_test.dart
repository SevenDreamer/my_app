import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/gamepad/latency_probe.dart';

void main() {
  group('LatencyMeter', () {
    test('对时算时钟差，按键事件按奇偶配对产出延迟样本', () {
      var now = 100000;
      final meter = LatencyMeter(now: () => now);
      // c1=1000 s1=1510 s2=1511 c2=1002 → θ = ((1510-1000)+(1511-1002))/2 = 509.5
      meter.ingestSyncAck(1000, 1510, 1511, 1002);

      // 偶数拍=Down。控制端 t1=200000（其时钟）；θ≈510 → 本机收到时刻 ≈199490
      now = 199490;
      meter.ingestBeat(0, 200000);
      // 本机 199520 收到按下 → 控制端时钟 200030 → 延迟 30ms
      now = 199520;
      meter.onKeyEvent(down: true);

      expect(meter.stats, isNotNull);
      expect(meter.stats, contains('平均 30ms'));
      expect(meter.stats, contains('丢包 0'));
    });

    test('奇数拍=Up：抬起事件配对奇数节拍', () {
      var now = 5000;
      final meter = LatencyMeter(now: () => now);
      meter.ingestSyncAck(0, 0, 0, 0); // θ = 0

      meter.ingestBeat(1, 5000); // 奇拍（Up）
      now = 5025;
      meter.onKeyEvent(down: false);

      expect(meter.stats, contains('平均 25ms'));
    });

    test('超时节拍计丢包回收——丢报告不错位配对', () {
      var now = 1000;
      final meter = LatencyMeter(now: () => now);
      meter.ingestSyncAck(0, 0, 0, 0); // θ = 0

      meter.ingestBeat(0, 1000); // 本应对应 Down，但其报告在蓝牙层丢了
      now = 1200; // 超过 kBeatTtlMs=150
      meter.ingestBeat(2, 1200); // 新偶拍进来 → 回收 seq0（计丢包）
      now = 1230;
      meter.onKeyEvent(down: true); // 应配到 seq2 而不是错位的 seq0

      expect(meter.stats, contains('平均 30ms'));
      expect(meter.stats, contains('丢包 1'));
    });

    test('无对时/无节拍时不产样本', () {
      final meter = LatencyMeter(now: () => 0);
      meter.onKeyEvent(down: true); // 无 θ：直接忽略
      meter.ingestSyncAck(0, 0, 0, 0);
      meter.onKeyEvent(down: true); // 无节拍：忽略
      expect(meter.stats, isNull);
    });
  });
}

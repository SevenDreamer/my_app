//! LinuxBaseService 数据解析单测（测试安全网第一批，2026-11-10）。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/services/linux_base_service.dart';

void main() {
  group('SnapshotInfo.tryParse', () {
    test('合法 map 解析出字段', () {
      final s = SnapshotInfo.tryParse({
        'name': 'snap-1',
        'createdAt': 1762740000000,
        'bytes': 8192,
        'note': '手动',
      });
      expect(s, isNotNull);
      expect(s!.name, 'snap-1');
      expect(s.bytes, 8192);
      expect(s.note, '手动');
      expect(s.createdAt.millisecondsSinceEpoch, 1762740000000);
    });

    test('缺 name/createdAt 返回 null（脏数据不进 UI）', () {
      expect(SnapshotInfo.tryParse({'createdAt': 1}), isNull);
      expect(SnapshotInfo.tryParse({'name': 'x'}), isNull);
      expect(SnapshotInfo.tryParse('not a map'), isNull);
      expect(SnapshotInfo.tryParse(null), isNull);
    });

    test('note 缺省为 null', () {
      final s = SnapshotInfo.tryParse({'name': 'a', 'createdAt': 0, 'bytes': -1});
      expect(s!.note, isNull);
    });
  });

  group('SnapshotProgress', () {
    test('ratio 正常区间', () {
      expect(const SnapshotProgress(done: 50, total: 100).ratio, 0.5);
    });

    test('total<=0 或越界夹紧', () {
      expect(const SnapshotProgress(done: 5, total: 0).ratio, 0);
      expect(const SnapshotProgress(done: 150, total: 100).ratio, 1);
    });
  });
}

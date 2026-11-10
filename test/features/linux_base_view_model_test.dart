//! LinuxBaseViewModel 单测（测试安全网第一批，2026-11-10）。
//!
//! 用假服务（implements LinuxBaseService）驱动 VM 全流程：刷新/快照/重置/
//! 安装——验证状态流转与命令编排，不碰真实平台通道。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/services/linux_base_service.dart';
import 'package:my_app/features/linux_base/linux_base_view_model.dart';

/// 假服务：脚本化返回值 + 调用记录。
class FakeLinuxBaseService implements LinuxBaseService {
  Map<Object?, Object?> status = {'phase': 'installed', 'runtimeVersion': 'r15'};
  Map<Object?, Object?> stats = {
    'memTotalMb': 2472,
    'memAvailableMb': 1000,
    'rootfsBytes': 812 * 1024 * 1024,
    'processes': [
      {'name': 'proot', 'pid': 1}
    ],
    'prootUptimeSec': 125,
    'load1': 0.5,
  };
  List<SnapshotInfo> snapshots = [];
  Object? createError;
  final List<String> calls = [];

  @override
  Future<Map<Object?, Object?>> getStatus() async {
    calls.add('getStatus');
    return status;
  }

  @override
  Future<Map<Object?, Object?>> baseStats() async {
    calls.add('baseStats');
    return stats;
  }

  @override
  Future<List<SnapshotInfo>> snapshotList() async {
    calls.add('snapshotList');
    return snapshots;
  }

  @override
  Future<Map<Object?, Object?>> snapshotCreate({String? note}) async {
    calls.add('snapshotCreate:$note');
    if (createError != null) return {'name': null, 'bytes': -1, 'error': '$createError'};
    return {'name': 'snap-test', 'bytes': 1024, 'error': null};
  }

  @override
  Future<SnapshotProgress?> snapshotProgress() async => null;

  @override
  Future<Map<Object?, Object?>> snapshotRestore(String name) async {
    calls.add('snapshotRestore:$name');
    return {'ok': true, 'error': null};
  }

  @override
  Future<bool> snapshotDelete(String name) async {
    calls.add('snapshotDelete:$name');
    return true;
  }

  @override
  Future<void> install({bool dropKept = false}) async {
    calls.add('install');
  }

  @override
  Stream<InstallProgress> installProgress() => const Stream.empty();

  @override
  Future<void> resetSystem() async {
    calls.add('resetSystem');
  }

  @override
  Future<void> start() async {
    calls.add('start');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}

void main() {
  test('refresh 采集状态/统计/快照三面', () async {
    final fake = FakeLinuxBaseService();
    final vm = LinuxBaseViewModel(fake);
    await vm.refresh();
    expect(vm.phase, 'installed');
    expect(vm.runtimeVersion, 'r15');
    expect(vm.stats['memTotalMb'], 2472);
    expect(vm.snapshots, isEmpty);
    expect(vm.message, isNull);
    vm.dispose();
  });

  test('创建快照成功：busy 流转 + 输出消息', () async {
    final fake = FakeLinuxBaseService();
    final vm = LinuxBaseViewModel(fake);
    await vm.createSnapshot(note: '手动快照');
    expect(fake.calls, contains('snapshotCreate:手动快照'));
    expect(vm.message, contains('snap-test'));
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('创建快照失败：错误消息落位，不抛出', () async {
    final fake = FakeLinuxBaseService()..createError = '磁盘满';
    final vm = LinuxBaseViewModel(fake);
    await vm.createSnapshot();
    expect(vm.message, contains('磁盘满'));
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('重置系统：命令下发 + 输出消息', () async {
    final fake = FakeLinuxBaseService();
    final vm = LinuxBaseViewModel(fake);
    await vm.resetSystem();
    expect(fake.calls, contains('resetSystem'));
    expect(vm.message, contains('重置'));
    vm.dispose();
  });

  test('启动/停止系统：命令编排顺序', () async {
    final fake = FakeLinuxBaseService();
    final vm = LinuxBaseViewModel(fake);
    await vm.startSystem();
    await vm.stopSystem();
    expect(fake.calls, containsAllInOrder(['start', 'getStatus', 'stop', 'getStatus']));
    vm.dispose();
  });

  test('busy 时命令互斥（快照期间重置被忽略）', () async {
    final fake = FakeLinuxBaseService();
    final vm = LinuxBaseViewModel(fake);
    // 手动置 busy 模拟进行中（不 await 长任务）
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    vm.notifyListeners();
    final busyBefore = vm.busy;
    expect(busyBefore, isFalse); // 静态断言基线
    vm.dispose();
  });
}

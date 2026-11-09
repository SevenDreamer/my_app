//! Linux 底座 ViewModel（P0）：系统状态 / 快照管理 / 启停命令。
//!
//! MVVM 铁律：View 只读本快照 + 调命令方法；数据经 [LinuxBaseService] 注入。
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/logging/sentry_bridge.dart';
import '../../data/services/linux_base_service.dart';

class LinuxBaseViewModel extends ChangeNotifier {
  LinuxBaseViewModel(this._service);

  final LinuxBaseService _service;

  /// 运行态（七态原值：notInstalled/installed/starting/running/…）。
  String phase = 'unknown';
  String? installedVersion;
  String? runtimeVersion;

  /// baseStats 采集面（load1/memMb/rootfsBytes/processes/prootUptimeSec）。
  Map<Object?, Object?> stats = const {};
  List<SnapshotInfo> snapshots = const [];

  /// 快照进行中状态。
  bool busy = false;
  SnapshotProgress? progress;
  String? message;

  Timer? _poll;
  bool _disposed = false;

  Future<void> refresh() async {
    try {
      final status = await _service.getStatus();
      phase = (status['phase'] as String?) ?? 'unknown';
      installedVersion = status['installedVersion'] as String?;
      runtimeVersion = (status['runtimeVersion'] as String?) ??
          (status['manifestVersion'] as String?);
      stats = await _service.baseStats();
      snapshots = await _service.snapshotList();
      message = null;
    } catch (e) {
      message = '状态读取失败：$e';
    }
    _notify();
  }

  Future<void> startSystem() async {
    SentryBridge.action('linux_base.start');
    try {
      await _service.start();
      message = '已发送启动指令';
    } catch (e) {
      message = '启动失败：$e';
    }
    SentryBridge.action('linux_base.start.out', {'result': message});
    await refresh();
  }

  Future<void> stopSystem() async {
    SentryBridge.action('linux_base.stop');
    try {
      await _service.stop();
      message = '已发送停止指令';
    } catch (e) {
      message = '停止失败：$e';
    }
    SentryBridge.action('linux_base.stop.out', {'result': message});
    await refresh();
  }

  /// 创建快照（分钟级）：轮询进度直至完成。
  Future<void> createSnapshot({String? note}) async {
    if (busy) return;
    SentryBridge.action('linux_base.snapshot_create');
    busy = true;
    message = '快照创建中…';
    _notify();
    _startPolling();
    try {
      final result = await _service.snapshotCreate(note: note);
      final error = result['error'] as String?;
      message = error == null
          ? '快照已创建：${result['name']}'
          : '快照失败：$error';
      SentryBridge.action('linux_base.snapshot_create.out',
          {'result': message, 'bytes': (result['bytes'] as num?)?.toInt() ?? -1});
    } catch (e) {
      message = '快照失败：$e';
      SentryBridge.action('linux_base.snapshot_create.out', {'result': message});
    } finally {
      busy = false;
      progress = null;
      _stopPolling();
      await refresh();
    }
  }

  /// 回滚到指定快照（系统会被停止，rootfs 整体替换）。
  Future<void> restoreSnapshot(SnapshotInfo snapshot) async {
    if (busy) return;
    SentryBridge.action('linux_base.snapshot_restore', {'name': snapshot.name});
    busy = true;
    message = '回滚中（系统将停止）…';
    _notify();
    _startPolling();
    try {
      final result = await _service.snapshotRestore(snapshot.name);
      final ok = result['ok'] == true;
      final error = result['error'] as String?;
      message = ok ? '回滚完成，请重新启动系统' : '回滚失败：${error ?? '未知错误'}';
    } catch (e) {
      message = '回滚失败：$e';
    } finally {
      SentryBridge.action('linux_base.snapshot_restore.out', {'result': message});
      busy = false;
      progress = null;
      _stopPolling();
      await refresh();
    }
  }

  Future<void> deleteSnapshot(SnapshotInfo snapshot) async {
    SentryBridge.action('linux_base.snapshot_delete', {'name': snapshot.name});
    try {
      await _service.snapshotDelete(snapshot.name);
      message = '已删除 ${snapshot.name}';
    } catch (e) {
      message = '删除失败：$e';
    }
    SentryBridge.action('linux_base.snapshot_delete.out', {'result': message});
    await refresh();
  }

  void _startPolling() {
    _stopPolling();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_disposed) return;
      progress = await _service.snapshotProgress();
      _notify();
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPolling();
    super.dispose();
  }
}

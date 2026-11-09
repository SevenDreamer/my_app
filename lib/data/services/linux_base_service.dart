//! Linux 底座域数据服务（P0）：`dsh/runtime` 通道的底座面封装。
//!
//! 归属语义见 docs/LINUX_BASE_PLAN.md：runtime 链即底座引擎（代码不改名）。
//! 本服务只封装底座 P0 需要的子集（状态/快照），与 dsh_go 域的 runtime_bridge
//! 互不引用（跨域隔离）。
import 'dart:async';

import 'package:flutter/services.dart';

/// 安装进度事件（dsh/runtime/events 的 progress 类型）。
class InstallProgress {
  const InstallProgress({required this.step, required this.done, required this.total});
  final String step;
  final int done;
  final int total;
  double get ratio => total <= 0 ? 0 : (done / total).clamp(0, 1);
}

/// 快照元数据（对应 Kotlin SnapshotManager.Snapshot 的 map 形态）。
class SnapshotInfo {
  const SnapshotInfo({
    required this.name,
    required this.createdAt,
    required this.bytes,
    this.note,
  });

  final String name;
  final DateTime createdAt;
  final int bytes;
  final String? note;

  static SnapshotInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    final createdAt = raw['createdAt'];
    if (name is! String || createdAt is! int) return null;
    return SnapshotInfo(
      name: name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      bytes: (raw['bytes'] as num?)?.toInt() ?? -1,
      note: raw['note'] as String?,
    );
  }
}

/// 快照进行中进度（done/total 字节）。
class SnapshotProgress {
  const SnapshotProgress({required this.done, required this.total});
  final int done;
  final int total;
  double get ratio => total <= 0 ? 0 : (done / total).clamp(0, 1);
}

class LinuxBaseService {
  static const _methods = MethodChannel('dsh/runtime');

  /// 运行态七态与安装信息（与 DSH 壳共享的状态机）。
  Future<Map<Object?, Object?>> getStatus() async =>
      await _methods.invokeMapMethod<Object?, Object?>('getStatus') ?? const {};

  /// 系统状态采集（负载/内存/rootfs 占用/进程/运行时长）。
  Future<Map<Object?, Object?>> baseStats() async =>
      await _methods.invokeMapMethod<Object?, Object?>('baseStats') ?? const {};

  Future<List<SnapshotInfo>> snapshotList() async {
    final list = await _methods.invokeListMethod<Object?>('snapshotList') ?? const [];
    return list.map(SnapshotInfo.tryParse).whereType<SnapshotInfo>().toList();
  }

  /// 创建快照（分钟级，后台线程执行）；返回结果 map：name/bytes/error。
  Future<Map<Object?, Object?>> snapshotCreate({String? note}) async =>
      await _methods.invokeMapMethod<Object?, Object?>('snapshotCreate', {'note': note}) ?? const {};

  /// 轮询快照进度；空闲时返回 null。
  Future<SnapshotProgress?> snapshotProgress() async {
    final map = await _methods.invokeMapMethod<Object?, Object?>('snapshotProgress');
    if (map == null) return null;
    final done = (map['done'] as num?)?.toInt() ?? 0;
    final total = (map['total'] as num?)?.toInt() ?? 0;
    return SnapshotProgress(done: done, total: total);
  }

  Future<Map<Object?, Object?>> snapshotRestore(String name) async =>
      await _methods.invokeMapMethod<Object?, Object?>('snapshotRestore', {'name': name}) ?? const {};

  Future<bool> snapshotDelete(String name) async =>
      await _methods.invokeMethod<bool>('snapshotDelete', {'name': name}) ?? false;

  /// 安装主系统（从资产解包 rootfs，分钟级；进度经 [events] 流）。
  Future<void> install({bool dropKept = false}) =>
      _methods.invokeMethod<void>('install', dropKept ? const {'dropKept': true} : null);

  /// 运行时事件流（status/progress/logs/notice），本域只解析 progress。
  Stream<InstallProgress> installProgress() {
    const events = EventChannel('dsh/runtime/events');
    return events.receiveBroadcastStream().map((raw) {
      final map = raw as Map<Object?, Object?>;
      return InstallProgress(
        step: map['step'] as String? ?? 'extract',
        done: (map['done'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
      );
    }).where((e) => true);
  }

  /// 重置系统（清 rootfs 回未安装态；快照保留）。
  Future<void> resetSystem() => _methods.invokeMethod<void>('resetSystem');

  /// 启动/停止主系统（与 DSH 壳共享的引擎命令）。
  Future<void> start() => _methods.invokeMethod<void>('start');

  Future<void> stop() => _methods.invokeMethod<void>('stop');
}

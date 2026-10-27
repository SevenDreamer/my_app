// 版权来源：DSHA（MIT）com.deepseekharness.app.util.InstallProcess —— 部分重构
//（CleanupFailure 语义先行；有界逐行读取 read()/Lines 随运行时接线轮移植）。
//! 进程回收失败的标记与识别：回收失败时携带精确进程句柄，
//! 仓库必须保留全局锁，不能把它当成普通取消完成。
library;

import 'dart:io' as io;

/// 回收失败（进程仍未退出）。[retry] 可再次尝试终止。
class InstallCleanupFailure implements Exception {
  InstallCleanupFailure({
    required this.process,
    required this.destroy,
    required this.awaitExit,
    this.cause,
  });

  /// 精确进程句柄（由运行时接线层提供具体类型）。
  final Object process;
  final void Function() destroy;

  /// 带超时等待退出（毫秒）。
  final bool Function(int millis) awaitExit;
  final Object? cause;

  @override
  String toString() => '本次进程仍未退出，不能开始下一任务';

  bool awaitExitFor(int millis) => awaitExit(millis);

  /// 再次尝试终止（吞掉终止异常，保持原版语义）。
  void retry() {
    try {
      destroy();
    } catch (_) {}
  }
}

/// 沿 cause 链找 [InstallCleanupFailure]（原版 `cleanupFailure` 等价）。
InstallCleanupFailure? installCleanupFailure(Object error) {
  Object? current = error;
  final seen = <Object>{};
  while (current != null && seen.add(current)) {
    if (current is InstallCleanupFailure) return current;
    try {
      current = (current as dynamic).cause as Object?;
    } catch (_) {
      current = null;
    }
  }
  return null;
}

/// 沿 cause 链判定取消（原版 `InstallPipeline.isCancellation` 等价）。
bool isCancellation(Object error) {
  Object? current = error;
  final seen = <Object>{};
  while (current != null && seen.add(current)) {
    if (current is InstallCancelledMarker) return true;
    try {
      current = (current as dynamic).cause as Object?;
    } catch (_) {
      current = null;
    }
  }
  return false;
}

/// 取消标记接口（[InstallCancelled] 实现）；供 cause 链识别。
abstract interface class InstallCancelledMarker {}

/// 具体 IO 异常（Dart 的 `io.IOException` 是抽象接口不能实例化；
/// [InstallFailure] 经 `message` 字段取因）。
class InstallIoException implements io.IOException {
  const InstallIoException(this.message);

  final String message;

  @override
  String toString() => message;
}

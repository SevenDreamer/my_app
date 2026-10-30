// 版权来源：DSHA（MIT）com.deepseekharness.app.util.InstallProcess —— 现代化重构，行为契约不变。
//! 有界逐行读取与进程回收：逐行输出有 16 KiB 行 / 4,096 字双阈值脱敏，
//! 私钥形态只回一行掩码；回收失败时携带精确进程句柄，
//! 仓库必须保留全局锁，不能把它当成普通取消完成。
//! 终止策略由宿主提供（原版兼容 Android 6 的分工不变）。
library;

import 'dart:async' as async;
import 'dart:convert' as convert;
import 'dart:io' as io;

import 'install_stage.dart';

/// 有界逐行读取子进程 stdout 至退出；超时/取消/回收语义与原版一致。
///
/// 语义保真点：退出码只在管道**排尽尾部**后才返回（原版
/// 「A final write can arrive between available() and exitValue()」）；
/// 超时、取消、回收失败（[InstallCleanupFailure]）三条路径逐字保留。
class InstallProcess {
  InstallProcess._();

  static Future<int> read(
    io.Process process, {
    required int timeoutMs,
    required bool cancellable,
    required bool Function() cancelled,
    required void Function(String line) output,
    required void Function(io.Process process) destroy,
  }) async {
    final poller = _ProcessPipePoller(process);
    final lines = _Lines(output);
    // 原版 RuntimeLauncher 的 redirectErrorStream(true)：stderr 并入同一流。
    // 不并线则 node -e 报错 / apt E: 全成诊断盲区（真机排障实证）。
    final stderrSub = process.stderr.listen((chunk) {
      lines.accept(chunk, chunk.length);
    });
    final deadline =
        DateTime.now().add(Duration(milliseconds: timeoutMs));
    Object? original;
    try {
      // 原版 process.getOutputStream().close()：不再向子进程写入。
      try {
        await process.stdin.close();
      } catch (_) {}
      while (true) {
        if (cancellable && cancelled()) throw const InstallCancelled();
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw InstallIoException(
              '命令超时（${timeoutMs ~/ 1000} 秒），当前步骤未完成，请重新检查');
        }
        final event = await poller.next(remaining);
        if (event.timedOut) {
          throw InstallIoException(
              '命令超时（${timeoutMs ~/ 1000} 秒），当前步骤未完成，请重新检查');
        }
        if (event.count > 0) {
          lines.accept(event.bytes!, event.count);
          continue;
        }
        final code = event.exitCode;
        if (code != null) {
          lines.flush();
          if (cancellable && cancelled()) throw const InstallCancelled();
          return code;
        }
      }
    } catch (error) {
      original = error;
      rethrow;
    } finally {
      await stderrSub.cancel();
      // 回收：未退出先 destroy，再给 2 秒等待；仍未退出 → 清理失败携句柄抛出。
      Object? termination;
      final exited = await _exited(process, timeout: const Duration(milliseconds: 50));
      if (!exited) {
        try {
          destroy(process);
        } catch (error) {
          termination = error;
        }
      }
      final reaped = await _exited(process, timeout: const Duration(seconds: 2));
      await poller.close();
      try {
        await process.stdin.close();
      } catch (_) {}
      if (!reaped) {
        final failure = InstallCleanupFailure(
          process: process,
          destroy: () => destroy(process),
          awaitExit: (millis) => _exited(process, timeout: Duration(milliseconds: millis)),
          cause: termination ?? original,
        );
        if (termination != null && original != null) {
          // 原版 addSuppressed(original)：终止异常为主因，原始异常保留可见。
          Error.throwWithStackTrace(
              failure, StackTrace.fromString('suppressed: $original'));
        }
        throw failure;
      }
    }
  }

  /// 等待进程退出；[timeout] 内未等到即返回 false（原版 `ProcessTermination.awaitExit`）。
  static Future<bool> _exited(io.Process process, {required Duration timeout}) async {
    try {
      await process.exitCode.timeout(timeout);
      return true;
    } on async.TimeoutException {
      return false;
    }
  }
}

/// 单事件：字节数 / 退出码 / 超时（原版 `ProcessPipePoller.Event`）。
class _PollerEvent {
  const _PollerEvent({this.count = 0, this.bytes, this.exitCode, this.timedOut = false});

  final int count;
  final List<int>? bytes;
  final int? exitCode;
  final bool timedOut;
}

/// 只消费已到达的管道字节，随后确认进程退出并排尽尾部
/// （原版 `ProcessPipePoller`：「Polls only available pipe bytes, then confirms
/// process exit and drains the final tail」）。
class _ProcessPipePoller {
  _ProcessPipePoller(this._process) {
    _stream = _process.stdout;
    _subscription = _stream.listen(_onData, onDone: _onDone, onError: _onError);
    // 订阅一次退出通知（原版 exitValue() 逐次探测的等价物）。
    _process.exitCode.then((code) {
      _exit = code;
    }, onError: (Object error) {
      _exitError = error;
    });
  }

  final io.Process _process;
  late final async.Stream<List<int>> _stream;
  late final async.StreamSubscription<List<int>> _subscription;
  final List<List<int>> _chunks = <List<int>>[];
  bool _done = false;
  Object? _error;
  int? _exit;
  Object? _exitError;

  void _onData(List<int> chunk) => _chunks.add(chunk);

  void _onDone() => _done = true;

  void _onError(Object error) {
    _error = error;
    _done = true;
  }

  Future<_PollerEvent> next(Duration remaining) async {
    // 本函数自带截止期（原版传 deadlineNanos 的等价物）：
    // 子进程无输出且未退出时不得自旋到天荒地老。
    final end = DateTime.now().add(remaining);
    while (true) {
      if (_error != null) {
        final error = _error!;
        _error = null;
        // 管道错误等价原版 IOException 路径：向上抛出，回收逻辑在 finally 兜底。
        throw error;
      }
      if (_chunks.isNotEmpty) {
        final chunk = _chunks.removeAt(0);
        return _PollerEvent(count: chunk.length, bytes: chunk);
      }
      final code = _exitCode();
      if (code != null) {
        // A final write can arrive between the previous available() and exitValue().
        if (!_done) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          continue;
        }
        return _PollerEvent(exitCode: code);
      }
      if (_done) {
        // 管道已关但退出码未到：短暂等待退出信号。
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final late = _exitCode();
        if (late != null) return _PollerEvent(exitCode: late);
        return const _PollerEvent(timedOut: true);
      }
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) return const _PollerEvent(timedOut: true);
      final step =
          left < const Duration(milliseconds: 10) ? left : const Duration(milliseconds: 10);
      await Future<void>.delayed(step);
    }
  }

  int? _exitCode() {
    // exitCode Future 未完成 → 进程仍在运行（原版 IllegalThreadStateException 分支）。
    if (_exitError != null) {
      throw _exitError!;
    }
    return _exit;
  }

  Future<void> close() async {
    await _subscription.cancel();
  }
}

/// 有界逐行装配（原版 `InstallProcess.Lines`）：16 KiB 行 / 4,096 字双阈值，
/// 超限整行脱敏，私钥形态只回一行掩码。
class _Lines {
  _Lines(this.output);

  final void Function(String line) output;
  final List<int> line = <int>[];
  bool overflow = false;

  void accept(List<int> bytes, int count) {
    for (var i = 0; i < count; i++) {
      final byte = bytes[i];
      if (byte == 0x0d || byte == 0x0a) {
        flush();
      } else if (line.length < 16384) {
        line.add(byte);
      } else {
        overflow = true;
      }
    }
  }

  void flush() {
    final value = convert.utf8.decode(line, allowMalformed: true);
    line.clear();
    final hide = overflow || value.length > 4096;
    overflow = false;
    if (hide) {
      if (value.contains('-----BEGIN ') && value.contains('PRIVATE KEY-----')) {
        output('-----BEGIN PRIVATE KEY-----');
      }
      output('[输出行过长，已隐藏]');
    } else if (value.isNotEmpty) {
      output(value);
    }
  }
}

/// 沿 cause 链找 [InstallCleanupFailure]（原版 `cleanupFailure` 等价）。
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
  final Future<bool> Function(int millis) awaitExit;
  final Object? cause;

  @override
  String toString() => '本次进程仍未退出，不能开始下一任务';

  Future<bool> awaitExitFor(int millis) => awaitExit(millis);

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

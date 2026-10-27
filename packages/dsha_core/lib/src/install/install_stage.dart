// 版权来源：DSHA（MIT）com.deepseekharness.app.util.InstallTask / InstallStage /
// InstallFailure —— 现代化重构，行为契约不变。
//! 安装任务的线程安全状态模型：六步阶段、单飞锁、有界脱敏日志、取消语义。
//! 页面只读快照（[InstallTask.snapshot]），销毁页面不能释放任务的单飞锁。
//!
//! 持久化契约：阶段 ID 恒为 1..6（历史序列化数据继续可读）；枚举序号永不序列化。
import 'dart:collection';
import 'dart:io' as io;

import 'install_process.dart';
import 'sensitive_data.dart' as sensitive;

/// 六步安装阶段。ID 为持久化契约（1..6）。
enum InstallStage {
  environment(1),
  tools(2),
  node(3),
  pnpm(4),
  dsh(5),
  patches(6);

  const InstallStage(this.id);

  final int id;

  /// 按 ID 升序（= 枚举声明序）。
  static List<InstallStage> get ordered => InstallStage.values;

  /// 未知 ID 属序列化损坏：抛 `INSTALL_STAGE_ID`（与原版异常文案一致）。
  static InstallStage fromId(int id) {
    for (final value in InstallStage.values) {
      if (value.id == id) return value;
    }
    throw ArgumentError('INSTALL_STAGE_ID');
  }
}

/// 任务结局。
enum InstallOutcome { idle, running, succeeded, failed, cancelled }

/// 单步状态。
enum InstallStep { pending, running, ok, failed, skipped }

/// 取消请求（[InstallTask.checkCancelled] 抛出；编排层穿透不吞）。
class InstallCancelled implements Exception, InstallCancelledMarker {
  const InstallCancelled();

  @override
  String toString() => '任务已取消';
}

/// 稳定失败码 + 脱敏原因，不依赖异常 toString / 本地化类名。
class InstallFailure {
  const InstallFailure(this.stage, this.code, this.reason);

  final InstallStage stage;

  /// 形如 `INSTALL_ENVIRONMENT_IO`（`INSTALL_<STAGE>_<IO|INPUT|RUNTIME>`）。
  final String code;
  final String reason;

  factory InstallFailure.from(InstallStage stage, Object error) {
    final kind = error is io.IOException
        ? 'IO'
        : error is ArgumentError
            ? 'INPUT'
            : 'RUNTIME';
    var reason = sensitive.redact(_messageOf(error));
    if (reason == 'null') reason = error.runtimeType.toString();
    if (reason.length > 1200) reason = reason.substring(0, 1200);
    return InstallFailure(stage, 'INSTALL_${stage.name}_$kind', reason);
  }

  /// 原版取 `Throwable.getMessage()`；Dart 异常无统一 message 面，
  /// 优先 message 字段，缺失则 toString()。
  static String _messageOf(Object error) {
    try {
      final message = (error as dynamic).message;
      if (message != null) return message.toString();
    } catch (_) {}
    return error.toString();
  }

  String display() => '安装步骤失败（$code）：$reason';
}

/// 安装任务状态（原版 synchronized 语义由 Dart 单线程事件循环天然满足；
/// 快照克隆数组/字符串，调用方只读）。
class InstallTask {
  /// 六步显示名（界面与日志共用，属契约文案）。
  static const List<String> names = [
    'Linux 环境',
    '基础工具',
    'Node.js',
    'pnpm',
    'deepseek-harness',
    '运行补丁',
  ];

  static const int _logLimit = 48 * 1024;

  final ListQueue<String> _lines = ListQueue<String>();
  final List<InstallStep> _steps = List<InstallStep>.filled(6, InstallStep.pending);
  final List<String> _details =
      List<String>.filled(6, '尚未检查', growable: false);
  InstallOutcome _outcome = InstallOutcome.idle;
  bool _repair = false, _cancelRequested = false, _cancellable = true;
  bool _privateKey = false, _truncated = false;
  int _selected = 0, _current = 0, _logSize = 0;
  int _started = 0, _stageStarted = 0, _finished = 0, _revision = 0;
  String _phase = '尚未检查', _failure = '';
  // 页面每秒轮询一次；日志只有 append 时才变化，复用渲染结果避免反复拼接 48 KiB。
  int _cachedLogRevision = -1;
  String _cachedLog = '';
  final Stopwatch _clock = Stopwatch();

  int _now() => _clock.elapsedMicroseconds * 1000;

  int _elapsed(int now, int start) =>
      start == 0 ? 0 : ((now - start) ~/ 1000000000).clamp(0, 1 << 62);

  /// 开始一次运行；已在跑则返回 false（单飞锁）。
  bool start({required bool repair, required int selected}) {
    if (selected < 0 || selected > 6) {
      throw ArgumentError('安装步骤必须为 0—6');
    }
    if (_outcome == InstallOutcome.running) return false;
    _clock.reset();
    _clock.start();
    _repair = repair;
    _selected = selected;
    _outcome = InstallOutcome.running;
    _cancelRequested = false;
    _cancellable = true;
    _current = 0;
    _started = _stageStarted = _now();
    _finished = 0;
    _phase = '准备检查';
    _failure = '';
    _privateKey = _truncated = false;
    _lines.clear();
    _logSize = 0;
    _steps.fillRange(0, 6, InstallStep.pending);
    _details.fillRange(0, 6, '尚未检查');
    _revision++;
    _cachedLogRevision = -1;
    _cachedLog = '';
    return true;
  }

  /// 与取消请求共用锁；取消已到达时不能再进入写入阶段。
  void stage(int step, String label, {required bool cancellable}) {
    checkCancelled();
    _current = step;
    _phase = _safe(label);
    _stageStarted = _now();
    _cancellable = cancellable;
    if (step > 0) {
      _steps[step - 1] = InstallStep.running;
      _details[step - 1] = _safe(label);
    }
    append(label);
    _revision++;
  }

  /// 发布单步结论（1..6）。
  void result(int step, {required bool ok, required String detail}) {
    _steps[step - 1] = ok ? InstallStep.ok : InstallStep.failed;
    _details[step - 1] = _safe(detail);
    append('${ok ? '通过 · ' : '未通过 · '}${names[step - 1]}：$detail');
    _revision++;
  }

  /// 发布单步跳过。
  void skip(int step, String detail) {
    _steps[step - 1] = InstallStep.skipped;
    _details[step - 1] = _safe(detail);
    append('跳过 · ${names[step - 1]}：$detail');
    _revision++;
  }

  /// 请求取消；返回是否新受理。
  bool requestCancel() {
    if (_outcome != InstallOutcome.running || _cancelRequested) return false;
    _cancelRequested = true;
    append(_cancellable
        ? '已请求取消检查，正在结束探测进程…'
        : '已请求停止；等待当前修复完成安全收尾，再停止后续步骤。');
    _revision++;
    return true;
  }

  bool cancellationRequested() => _cancelRequested;

  /// 取消已到达则抛 [InstallCancelled]。
  void checkCancelled() {
    if (_cancelRequested) throw const InstallCancelled();
  }

  /// 取消后仍可报告必要收尾；此阶段不释放单飞或全局环境锁。
  void cleaningUp(String detail) {
    _phase = _safe(detail);
    _cancellable = false;
    _stageStarted = _now();
    append(detail);
  }

  /// 终局：RUNNING 步落终态；选中范围内的 PENDING 步在失败/取消时标未完成。
  void finish(InstallOutcome result, String detail) {
    if (_outcome != InstallOutcome.running) return;
    _outcome = result;
    _finished = _now();
    _phase = _safe(detail);
    _cancellable = false;
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i] == InstallStep.running ||
          (_steps[i] == InstallStep.pending &&
              (_selected == 0 || _selected == i + 1) &&
              (result == InstallOutcome.failed ||
                  result == InstallOutcome.cancelled))) {
        _steps[i] = result == InstallOutcome.failed
            ? InstallStep.failed
            : InstallStep.skipped;
        _details[i] = _safe('检查未完成：$detail');
      }
    }
    if (result == InstallOutcome.failed) _failure = _safe(detail);
    append(detail);
    _revision++;
  }

  /// 只保留脱敏后的有界日志；私钥块必须跨行隐藏，
  /// 不能逐行调用普通正则后直接保存。
  void append(String value) {
    for (final line in value.split(RegExp(r'\r?\n|\r'))) {
      if (line.isEmpty) continue;
      if (line.contains('-----BEGIN ') && line.contains('PRIVATE KEY-----')) {
        _privateKey = !line.contains('-----END ');
        // ignore: prefer_interpolation_to_compose_strings
        _addEntry('[私钥已隐藏]');
      } else if (_privateKey) {
        if (line.contains('-----END ') && line.contains('PRIVATE KEY-----')) {
          _privateKey = false;
        }
        continue;
      } else {
        _addEntry(_safe(line));
      }
    }
  }

  void _addEntry(String safeLine) {
    final entry = '[${_elapsed(_now(), _started)}s] $safeLine\n';
    _lines.addLast(entry);
    _logSize += entry.length;
    while (_logSize > _logLimit && _lines.isNotEmpty) {
      _logSize -= _lines.removeFirst().length;
      _truncated = true;
    }
    _revision++;
  }

  static String _safe(String value) {
    if (value.contains('-----BEGIN ') && value.contains('PRIVATE KEY-----')) {
      return '[私钥已隐藏]';
    }
    // 超长行整体隐藏，避免截断破坏带引号凭据的识别边界。
    if (value.length > 4096) return '[输出行过长，已隐藏]';
    return sensitive.redact(_stripControl(value));
  }

  /// 剥 ANSI 转义序列与控制字符（保留 \t）——原版两条正则的等价实现
  ///（Dart 正则不支持 Java 的字符类交集 `[\\p{Cntrl}&&[^\\t]]`）。
  static String _stripControl(String value) {
    final noAnsi =
        value.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
    final buffer = StringBuffer();
    for (final rune in noAnsi.runes) {
      if (rune == 0x09 || rune >= 0x20 && rune != 0x7F) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// 只读快照；日志渲染结果按 revision 缓存。
  InstallSnapshot snapshot() {
    final now = _outcome == InstallOutcome.running ? _now() : _finished;
    if (_cachedLogRevision != _revision) {
      final log = StringBuffer(_truncated ? '[较早输出已省略，仅保留最近 48 KiB]\n' : '');
      for (final line in _lines) {
        log.write(line);
      }
      _cachedLog = log.toString();
      _cachedLogRevision = _revision;
    }
    return InstallSnapshot(
      outcome: _outcome,
      repair: _repair,
      selected: _selected,
      current: _current,
      cancelRequested: _cancelRequested,
      cancellable: _cancellable,
      phase: _safe(_phase),
      failure: _failure,
      steps: List<InstallStep>.unmodifiable(_steps),
      details: List<String>.unmodifiable(_details),
      log: _cachedLog,
      elapsedSeconds: _elapsed(now, _started),
      stageSeconds: _elapsed(now, _stageStarted),
      revision: _revision,
    );
  }
}

/// 页面渲染用只读快照。
class InstallSnapshot {
  const InstallSnapshot({
    required this.outcome,
    required this.repair,
    required this.selected,
    required this.current,
    required this.cancelRequested,
    required this.cancellable,
    required this.phase,
    required this.failure,
    required this.steps,
    required this.details,
    required this.log,
    required this.elapsedSeconds,
    required this.stageSeconds,
    required this.revision,
  });

  final InstallOutcome outcome;
  final bool repair, cancelRequested, cancellable;
  final int selected, current;
  final String phase, failure, log;
  final List<InstallStep> steps;
  final List<String> details;
  final int elapsedSeconds, stageSeconds, revision;

  bool busy() => outcome == InstallOutcome.running;
}

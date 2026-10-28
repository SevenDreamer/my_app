// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenInput —— 现代化重构，行为契约不变。
//! 仅供特权 core：优先反射直接提交事件（不启进程），反射不可用时退到 `input -d <displayId>` 命令。
//! 探测与构造**绝不抛异常**：隐藏成员缺失、hidden-API 策略拒绝、系统命令不存在都只导致降级，
//! 不再让 `/vscreen/create` 连坐失败（issue #113）。查找成功不等于调用可用：反射后端第一次被拒
//! 就切到命令后端，而不是让每一次动作都以「被拒绝」告终。
//! 「提交后的异常保留 UNKNOWN；降级只影响后续新动作，当前动作绝不重放。」
library;

import 'input_policy.dart';
import 'stroke.dart';

/// 事件规格（原版 `MotionEvent`/`KeyEvent` 构造参数；Android 面按此实例化真实事件）。
class InputEventSpec {
  const InputEventSpec.touch({
    required this.action,
    required this.downTime,
    required this.eventTime,
    required this.x,
    required this.y,
  })  : keyCode = 0,
        isKey = false;

  const InputEventSpec.key({
    required this.action,
    required this.downTime,
    required this.eventTime,
    required this.keyCode,
  })  : x = 0,
        y = 0,
        isKey = true;

  final bool isKey;
  final int action; // touch: 0=DOWN 1=UP 2=MOVE 3=CANCEL；key: 0=DOWN 1=UP
  final int downTime, eventTime;
  final double x, y;
  final int keyCode;
}

/// 事件提交面（原版反射 `setDisplayId` + `injectInputEvent` 链；缝）。
/// 返回是否被输入系统接受；抛异常＝运行期被拒（触发降级判定）。
typedef SubmitInputEvent = bool Function(int displayId, InputEventSpec event);

/// 命令执行结果（原版 ProcessBuilder 段的可观测事实；缝）。
class CommandOutcome {
  const CommandOutcome({
    this.started = true,
    this.timedOut = false,
    this.outputTruncated = false,
    this.readerStuck = false,
    this.exit,
    this.text = '',
  });

  /// 进程都没起来（原版 `process == null`）。
  final bool started;
  final bool timedOut;
  final bool outputTruncated;
  final bool readerStuck;
  final int? exit;
  final String text;
}

typedef RunCommandFn = CommandOutcome Function(List<String> argv, int timeoutMs);

/// 输入探测面（原版反射查找结论；缝）。
class InputApiProbe {
  const InputApiProbe({
    required this.managerPresent,
    required this.injectPresent,
    required this.setDisplayPresent,
    this.missingNote = '',
  });

  final bool managerPresent, injectPresent, setDisplayPresent;

  /// 原版 `missing` 串：`input-api: <cause>` / `InputManager.getInstance(invoke-null)` /
  /// 缺 setDisplay 时逗号追加 `InputEvent.setDisplayId(int)`。
  final String missingNote;
}

/// 虚拟屏输入（原版 `VirtualScreenInput`）。
class VscreenInput {
  VscreenInput._({
    required this.display,
    required String backend,
    required String unavailable,
    required this.submit,
    required RunCommandFn commandRunner,
    required bool commandAvailable,
    this.uptime = _wallUptime,
  })  : _backend = backend,
        _unavailable = unavailable,
        _runCommand = commandRunner,
        _commandAvailable = commandAvailable,
        stroke = VscreenStroke(display);

  final int display;
  final VscreenStroke stroke;
  final SubmitInputEvent submit;
  final RunCommandFn _runCommand;
  final bool _commandAvailable;

  /// 单调毫时钟（原版 `SystemClock.uptimeMillis`）。
  final int Function() uptime;
  String _backend;
  String _unavailable;
  VscreenInputResult _lastResult = VscreenInputResult.REJECTED;
  VscreenInputResult _strokeResult = VscreenInputResult.REJECTED;

  /// 测试构造（原版 `commandForTest`）。
  factory VscreenInput.commandForTest(int display, RunCommandFn runner,
          {int Function()? uptime}) =>
      VscreenInput._(
        display: display,
        backend: VscreenInputPolicy.backendCommand,
        unavailable: '',
        submit: (_, __) => false,
        commandRunner: runner,
        commandAvailable: true,
        uptime: uptime ?? _wallUptime,
      );

  /// 探测一次并选定后端；任何探测失败都只降级，不抛给调用方。
  factory VscreenInput.create({
    required int display,
    required InputApiProbe Function() probe,
    required SubmitInputEvent submit,
    required RunCommandFn commandRunner,
    required bool commandAvailable,
    int Function()? uptime,
  }) {
    late InputApiProbe result;
    try {
      result = probe();
    } catch (failure) {
      result = InputApiProbe(
        managerPresent: false,
        injectPresent: false,
        setDisplayPresent: false,
        missingNote: 'input-api: $failure',
      );
    }
    var missing = result.missingNote;
    if (!result.setDisplayPresent) {
      missing +=
          '${missing.isEmpty ? '' : ','}${VscreenInputPolicy.memberSetDisplay}';
    }
    final backend = VscreenInputPolicy.backend(result.managerPresent,
        result.injectPresent, result.setDisplayPresent, commandAvailable);
    return VscreenInput._(
      display: display,
      backend: backend,
      unavailable: backend == VscreenInputPolicy.backendReflection ? '' : missing,
      submit: submit,
      commandRunner: commandRunner,
      commandAvailable: commandAvailable,
      uptime: uptime ?? _wallUptime,
    );
  }

  /// 当前后端：reflection / input-command / unavailable。
  String backend() => _backend;

  /// 缺失的隐藏成员、调用失败原因或降级原因；反射后端可用时为空串。
  String unavailableReason() => _unavailable;

  /// 是否真的能注入输入；false 时虚拟屏仍可看，但点不动。
  bool available() => _backend != VscreenInputPolicy.backendUnavailable;

  VscreenInputResult lastResult() => _lastResult;

  VscreenInputResult _remember(VscreenInputResult result) => _lastResult = result;

  /// 触摸（action: 0=DOWN 1=UP 2=MOVE 3=CANCEL）。
  VscreenInputResult touch(String id, int action, double x, double y) {
    final now = _uptime();
    if (_backend == VscreenInputPolicy.backendReflection) {
      return _remember(_reflectTouch(id, action, x, y, now));
    }
    if (_backend == VscreenInputPolicy.backendCommand) {
      return _remember(_commandTouch(id, action, x, y, now));
    }
    return _remember(VscreenInputResult.REJECTED);
  }

  bool active() => stroke.active();

  void expire() {
    if (!stroke.stale(_uptime())) return;
    try {
      cancel();
    } on Exception {
      stroke.cancel(stroke.id());
    }
  }

  void cancel() {
    if (!stroke.active()) return;
    if (_backend == VscreenInputPolicy.backendReflection) {
      _reflectCancel(_uptime());
      return;
    }
    // 命令后端在抬起前没有注入任何中间态：丢掉记录即可。取消绝不能重放成一条手势。
    stroke.cancel(stroke.id());
  }

  VscreenInputResult key(int code) {
    if (_backend == VscreenInputPolicy.backendReflection) {
      return _remember(_reflectKey(code));
    }
    if (_backend == VscreenInputPolicy.backendCommand) {
      return _remember(run(
          VscreenInputPolicy.keyArgs(display, code),
          VscreenInputPolicy.commandTimeoutMs(0)));
    }
    return _remember(VscreenInputResult.REJECTED);
  }

  VscreenInputResult text(String text) {
    if (!_commandAvailable) return _remember(VscreenInputResult.REJECTED);
    return _remember(run(
      [
        VscreenInputPolicy.command,
        '-d',
        '$display',
        'text',
        text.replaceAll(' ', '%s'),
      ],
      VscreenInputPolicy.commandTimeoutMs(0),
    ));
  }

  /// 反射后端：逐事件直接提交，按下/移动/抬起都即时生效。
  VscreenInputResult _reflectTouch(String id, int action, double x, double y, int now) {
    if (action == 0 /* ACTION_DOWN */) {
      if (stroke.active()) _reflectCancel(now);
      stroke.down(id, x, y, now);
      _strokeResult = VscreenInputResult.REJECTED;
    } else if (action == 2 /* ACTION_MOVE */) {
      if (!stroke.move(id, x, y, now)) return VscreenInputResult.REJECTED;
    } else if (action == 1 /* ACTION_UP */ || action == 3 /* ACTION_CANCEL */) {
      if (!stroke.active() || id != stroke.id()) return VscreenInputResult.REJECTED;
    } else {
      return VscreenInputResult.REJECTED;
    }
    final cancelled = action == 3;
    final event = InputEventSpec.touch(
      action: action,
      downTime: stroke.downAt(),
      eventTime: now,
      x: cancelled ? stroke.lastX() : x,
      y: cancelled ? stroke.lastY() : y,
    );
    try {
      final result = _send(event);
      _strokeResult = VscreenInputResult.after(_strokeResult, result);
      return _strokeResult;
    } finally {
      if (action == 1 || cancelled) stroke.cancel(id);
    }
  }

  /// 反射后端补发上一笔手势的 CANCEL：不补的话应用会停在按下态。
  void _reflectCancel(int now) {
    final event = InputEventSpec.touch(
      action: 3,
      downTime: stroke.downAt(),
      eventTime: now,
      x: stroke.lastX(),
      y: stroke.lastY(),
    );
    try {
      _remember(VscreenInputResult.after(_strokeResult, _send(event)));
    } finally {
      stroke.cancel(stroke.id());
    }
  }

  VscreenInputResult _reflectKey(int code) {
    final at = _uptime();
    final first = _send(InputEventSpec.key(
        action: 0, downTime: at, eventTime: at, keyCode: code));
    if (first == VscreenInputResult.REJECTED) return first;
    return VscreenInputResult.after(
        first,
        _send(InputEventSpec.key(
            action: 1, downTime: at, eventTime: at, keyCode: code)));
  }

  /// 提交一个事件。隐藏 API 的查找与调用会在不同阶段被拒，只有运行期失败才知道它真的用不了。
  VscreenInputResult _send(InputEventSpec event) {
    var submitting = false;
    try {
      submitting = true;
      return submit(display, event)
          ? VscreenInputResult.ACCEPTED
          : VscreenInputResult.REJECTED;
    } catch (refused) {
      // 仅为后续新动作切换后端；当前提交可能已执行，绝不在另一个后端重放。
      _degradeToCommand(refused);
      return submitting ? VscreenInputResult.UNKNOWN : VscreenInputResult.REJECTED;
    }
  }

  /// 反射后端运行期被拒：后续使用命令后端，命令缺失则只读；原因写进 status。
  void _degradeToCommand(Object refused) {
    if (_backend != VscreenInputPolicy.backendReflection) return;
    _backend = _commandAvailable
        ? VscreenInputPolicy.backendCommand
        : VscreenInputPolicy.backendUnavailable;
    _unavailable = 'reflection: $refused';
    stroke.cancel(stroke.id());
  }

  /// 命令后端：按下/移动只记录，抬起时用一次 `input -d <displayId> tap|swipe` 重放；
  /// 取消只丢弃记录（取消不是抬起，绝不重放）。中间态对界面不可见。
  VscreenInputResult _commandTouch(String id, int action, double x, double y, int now) {
    if (action == 0) {
      stroke.down(id, x, y, now);
      return VscreenInputResult.ACCEPTED;
    }
    if (action == 2) {
      return stroke.move(id, x, y, now)
          ? VscreenInputResult.ACCEPTED
          : VscreenInputResult.REJECTED;
    }
    if (action == 3) {
      return stroke.cancel(id)
          ? VscreenInputResult.ACCEPTED
          : VscreenInputResult.REJECTED;
    }
    if (action != 1) return VscreenInputResult.REJECTED;
    final release = stroke.up(id, x, y, now);
    if (!release.replays()) return VscreenInputResult.REJECTED;
    return run(release.argv!, VscreenInputPolicy.commandTimeoutMs(release.durationMs));
  }

  VscreenInputResult run(List<String> argv, int timeoutMs) =>
      _remember(judgeCommand(_runCommand(argv, timeoutMs)));

  /// 有界回退命令判定（原版 `runCommand` 决策表）：超时/输出截断/读线程未尽/非零退出码/
  /// 输出含 Error|Exception 都保守判 UNKNOWN；进程都没起来才是 REJECTED。
  static VscreenInputResult judgeCommand(CommandOutcome outcome) {
    if (!outcome.started) return VscreenInputResult.REJECTED;
    if (outcome.timedOut) return VscreenInputResult.UNKNOWN;
    if (outcome.readerStuck || outcome.outputTruncated) return VscreenInputResult.UNKNOWN;
    if (outcome.exit == null || outcome.exit != 0) return VscreenInputResult.UNKNOWN;
    return outcome.text.contains('Error') || outcome.text.contains('Exception')
        ? VscreenInputResult.UNKNOWN
        : VscreenInputResult.ACCEPTED;
  }

  int _uptime() => uptime();
}

int _wallUptime() => DateTime.now().millisecondsSinceEpoch;

// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenPreviewInputGate + util.TouchGestureDispatch —— 现代化重构，行为契约不变。
//! 本地原生预览/输入准入；不授权任何远端帧或输入。
//! 「One gesture owns exactly one input route; unknown stream results never become discrete replay.」
library;

/// 预览/手势互斥准入门（原版 `VirtualScreenPreviewInputGate`）：fetch 与 gesture 互斥，
/// fetch 引用计数，offered 释放生产侧。
class PreviewInputGate {
  _Fetch? _fetching;
  _Gesture? _gesture;

  /// 开始一次取帧；已有取帧/手势时返回 null。
  FetchHold? beginPreview() {
    if (_fetching != null || _gesture != null) return null;
    final fetch = _Fetch(this);
    _fetching = fetch;
    return fetch;
  }

  /// 开始一次手势；已有取帧/手势时返回 null。
  GestureHold? beginGesture() {
    if (_fetching != null || _gesture != null) return null;
    final gesture = _Gesture(this);
    _gesture = gesture;
    return gesture;
  }
}

/// 取帧占用（原版 `Fetch`+`Hold`）。
abstract class FetchHold {
  /// 续留一份解码/待发引用；非当前取帧或已清零返回 null。
  AutoCloseHold? retain();

  /// 生产侧完成供给（原版 `offered`）。
  void offered();
}

/// 通用占用（原版 `Hold implements AutoCloseable`）。
abstract class AutoCloseHold {
  void close();
}

/// 手势占用（原版 `Gesture implements AutoCloseable`）。
abstract class GestureHold implements AutoCloseHold {}

class _Fetch implements FetchHold {
  _Fetch(this._gate);

  final PreviewInputGate _gate;
  int _references = 1;
  late final _Hold _producer = _Hold(this);

  @override
  AutoCloseHold? retain() {
    if (!identical(_gate._fetching, this) || _references <= 0) return null;
    _references++;
    return _Hold(this);
  }

  @override
  void offered() {
    _producer.close();
  }
}

class _Hold implements AutoCloseHold {
  _Hold(this._fetch);

  final _Fetch _fetch;
  bool _closed = false;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _fetch._references--;
    if (_fetch._references == 0 && identical(_fetch._gate._fetching, _fetch)) {
      _fetch._gate._fetching = null;
    }
  }
}

class _Gesture implements GestureHold {
  _Gesture(this._gate);

  final PreviewInputGate _gate;
  bool _closed = false;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (identical(_gate._gesture, this)) _gate._gesture = null;
  }
}

/// 手势输出面（原版 `TouchGestureDispatch.Sink`）。
abstract class GestureSink {
  void stream(int action, double x, double y);

  void input(double x1, double y1, double x2, double y2, int duration, bool tap);
}

/// 手势合成（原版 `TouchGestureDispatch`）：一次手势只占一条输入路由。
class TouchGestureDispatch {
  // 原版常量名（Java DOWN/UP/MOVE/CANCEL）；与实例方法异名共存。
  // ignore: constant_identifier_names
  static const int DOWN = 0, UP = 1, MOVE = 2, CANCEL = 3;

  _Route _route = _Route.idle;
  GestureSink? _sink;
  double _x = 0, _y = 0;

  static bool _point(List<double>? value) =>
      value != null &&
      value.length == 2 &&
      !value[0].isNaN &&
      !value[1].isNaN &&
      !value[0].isInfinite &&
      !value[1].isInfinite &&
      value[0] >= 0 &&
      value[1] >= 0;

  void down(GestureSink? target, bool streamAvailable, bool enabled, List<double>? start) {
    cancel();
    _sink = target;
    _route = _Route.consumed;
    if (target == null || !enabled || !_point(start)) return;
    _x = start![0];
    _y = start[1];
    _route = streamAvailable ? _Route.stream : _Route.discrete;
    if (_route == _Route.stream) {
      try {
        target.stream(DOWN, _x, _y);
      } catch (unknown) {
        cancel();
      }
    }
  }

  void move(List<double>? location) {
    if (_route != _Route.stream) return;
    if (!_point(location)) {
      cancel();
      return;
    }
    try {
      _sink?.stream(MOVE, location![0], location[1]);
    } catch (unknown) {
      cancel();
    }
  }

  bool up(List<double>? end, int duration, bool tap) {
    final chosen = _route;
    final target = _sink;
    _route = _Route.idle;
    _sink = null;
    if (chosen == _Route.stream) {
      if (!_point(end)) {
        try {
          target?.stream(CANCEL, 0, 0);
        } catch (unknown) {
          // 原版吞掉。
        }
        return false;
      }
      try {
        target?.stream(UP, end![0], end[1]);
        return true;
      } catch (unknown) {
        try {
          target?.stream(CANCEL, 0, 0);
        } catch (unavailable) {
          // 原版吞掉。
        }
      }
      return false;
    }
    if (chosen == _Route.discrete && _point(end)) {
      try {
        target?.input(
            _x,
            _y,
            end![0],
            end[1],
            duration < 50 ? 50 : (duration > 3000 ? 3000 : duration),
            tap);
        return true;
      } catch (unknown) {
        // 原版吞掉。
      }
    }
    return false;
  }

  void cancel() {
    final chosen = _route;
    final target = _sink;
    _route = _Route.consumed;
    _sink = null;
    if (chosen == _Route.stream && target != null) {
      try {
        target.stream(CANCEL, 0, 0);
      } catch (unknown) {
        // 原版吞掉。
      }
    }
  }
}

enum _Route { idle, stream, discrete, consumed }

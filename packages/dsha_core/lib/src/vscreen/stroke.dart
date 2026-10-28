// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenStroke —— 现代化重构，行为契约不变。
//! 命令后端的单次手势状态机（纯逻辑）：按下/移动只记录，抬起时决定怎么重放，取消一律丢弃。
//! 「取消不是抬起，绝不能反向注入一条手势」；「长按被当成点击」由 LONG_PRESS_MS 门挡。
library;

import 'input_policy.dart';

/// 手势状态机（原版 `VirtualScreenStroke`）。
class VscreenStroke {
  /// 超过这个时长没有新事件的手势算悬空，由看门狗丢弃。
  static const int staleMs = 3000;

  /// 位移在阈值内但按住超过这个时长，按长按重放（起止同点的 swipe 就是按住）。
  static const int longPressMs = 400;

  VscreenStroke(this.display);

  final int display;
  String _id = '';
  double _startX = 0, _startY = 0, _lastX = 0, _lastY = 0;
  int _downAt = 0, _lastAt = 0;

  /// 按下：开始一次新手势；已有未收尾的手势直接丢弃（命令后端没有已注入的中间态）。
  void down(String id, double x, double y, int now) {
    _id = id;
    _startX = x;
    _startY = y;
    _lastX = x;
    _lastY = y;
    _downAt = now;
    _lastAt = now;
  }

  /// 移动：id 不匹配或没有进行中的手势返回 false，只更新记录。
  bool move(String id, double x, double y, int now) {
    if (!active() || _id != id) return false;
    _lastX = x;
    _lastY = y;
    _lastAt = now;
    return true;
  }

  /// 抬起：给出重放计划。位移在点击阈值内且按住不到 [longPressMs] 才算点击，
  /// 否则用起点到终点的 swipe（起止同点＝按住）重放，时长就是真实按住时长。
  StrokeRelease up(String id, double x, double y, int now) {
    if (!active() || _id != id) return StrokeRelease.none;
    final fromX = _startX, fromY = _startY;
    final held = now - _downAt < 0 ? 0 : now - _downAt;
    _reset();
    if (VscreenInputPolicy.isTap(fromX, fromY, x, y) && held < longPressMs) {
      return StrokeRelease(VscreenInputPolicy.tapArgs(display, x, y), held);
    }
    return StrokeRelease(
        VscreenInputPolicy.swipeArgs(display, fromX, fromY, x, y, held), held);
  }

  /// 取消：丢弃进行中的手势，返回是否真的丢弃了。**绝不重放**——取消不是抬起。
  bool cancel(String? id) {
    if (!active() || (id != null && id.isNotEmpty && _id != id)) return false;
    _reset();
    return true;
  }

  /// 悬空手势（超过 [staleMs] 没有新事件）：丢弃并返回是否丢弃了。
  bool expire(int now) {
    if (!stale(now)) return false;
    _reset();
    return true;
  }

  /// 是否已经悬空（进行中且超过 [staleMs] 没有新事件）。
  bool stale(int now) => active() && now - _lastAt > staleMs;

  bool active() => _id.isNotEmpty;

  /// 进行中手势的 id；没有手势时为空串（反射后端补发 CANCEL 用）。
  String id() => _id;

  /// 手势按下时刻（反射后端构造事件的 downTime）。
  int downAt() => _downAt;

  /// 手势最后已知坐标：反射后端补发 CANCEL 用它，避免把取消注到调用方传的 (0,0)。
  double lastX() => _lastX;

  double lastY() => _lastY;

  void _reset() {
    _id = '';
    _startX = 0;
    _startY = 0;
    _lastX = 0;
    _lastY = 0;
    _downAt = 0;
    _lastAt = 0;
  }
}

/// 收尾结果（原版 `Release`）：要执行的命令参数与按住时长；无手势时 [replays] 为 false。
class StrokeRelease {
  const StrokeRelease(this.argv, this.durationMs);

  /// 没有可重放的手势（取消、id 不匹配、本来就没有手势）。
  static const StrokeRelease none = StrokeRelease(null, 0);

  final List<String>? argv;
  final int durationMs;

  bool replays() => argv != null;
}

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.{AccessibilityTreeBudget,AccessibilityDumpBounds,ScreenTarget} —— 现代化重构，行为契约不变。
//! 无障碍树预算、矩形可用性、显示内窗口身份三小件（纯逻辑）。
library;

/// 树遍历预算（原版 `AccessibilityTreeBudget`）：与产出多少有用节点无关地限界遍历工作。
class AccessibilityTreeBudget {
  static const int visitLimit = 4096, outputLimit = 200, depthLimit = 24;

  int _visits = 0;

  int visits() => _visits;

  bool exhausted() => _visits >= visitLimit;

  bool enter(int depth, int outputCount) {
    if (depth > depthLimit || outputCount >= outputLimit || exhausted()) return false;
    _visits++;
    return true;
  }

  bool childSlot(int outputCount) {
    if (outputCount >= outputLimit || exhausted()) return false;
    _visits++;
    return true;
  }
}

/// 矩形可用性（原版 `AccessibilityDumpBounds`）。
///
/// 文字节点可以零面积：`(0,370,0,499)` 这种只有高度的矩形仍是合法输入。只有反序矩形
/// （`right < left` 或 `bottom < top`）不是「空节点」而是噪声——它的四条边没有一条
/// 能用来定位（issue #143：同一份判定写在两处，只有一处跟着修）。
abstract final class AccessibilityDumpBounds {
  static bool ordered(int left, int top, int right, int bottom) =>
      right >= left && bottom >= top;

  /// 节点是否值得报给调用方：有可读文字或可操作能力，且矩形能用来定位。
  static bool reportable(
          bool labeled, bool actionable, int left, int top, int right, int bottom) =>
      (labeled || actionable) && ordered(left, top, right, bottom);
}

/// 一个显示上观察到的包/窗口身份（原版 `ScreenTarget`）；绝不回退到别的显示。
class ScreenTarget {
  ScreenTarget(this.displayId, this.windowId, String packageName)
      : packageName = packageName;

  final int displayId, windowId;
  final String packageName;

  bool matches(ScreenTarget? current) =>
      current != null &&
      displayId == current.displayId &&
      windowId >= 0 &&
      windowId == current.windowId &&
      packageName == current.packageName;
}

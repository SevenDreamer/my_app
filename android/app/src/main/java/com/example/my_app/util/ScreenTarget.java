package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ScreenTarget —— 全量搬码，包名适配，行为契约不变。

/** Package/window identity observed on one display; no fallback to another display. */
public final class ScreenTarget {
  public final int displayId, windowId;
  public final String packageName;

  public ScreenTarget(int displayId, int windowId, String packageName) {
    this.displayId = displayId;
    this.windowId = windowId;
    this.packageName = packageName == null ? "" : packageName;
  }

  public boolean matches(ScreenTarget current) {
    return current != null
        && displayId == current.displayId
        && windowId >= 0
        && windowId == current.windowId
        && packageName.equals(current.packageName);
  }
}

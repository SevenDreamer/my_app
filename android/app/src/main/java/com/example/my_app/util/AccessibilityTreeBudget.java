package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.AccessibilityTreeBudget —— 全量搬码，包名适配，行为契约不变。

/** Bounds traversal work independently of how many nodes produce useful output. */
public final class AccessibilityTreeBudget {
  public static final int VISIT_LIMIT = 4096, OUTPUT_LIMIT = 200, DEPTH_LIMIT = 24;
  private int visits;

  public int visits() {
    return visits;
  }

  public boolean exhausted() {
    return visits >= VISIT_LIMIT;
  }

  public boolean enter(int depth, int outputCount) {
    if (depth > DEPTH_LIMIT || outputCount >= OUTPUT_LIMIT || exhausted()) return false;
    visits++;
    return true;
  }

  public boolean childSlot(int outputCount) {
    if (outputCount >= OUTPUT_LIMIT || exhausted()) return false;
    visits++;
    return true;
  }
}

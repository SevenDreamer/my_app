package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.NotificationIds —— 全量搬码，包名适配，行为契约不变。

/** Stable app notification namespace; existing Android identifiers stay unchanged. */
public final class NotificationIds {
  private NotificationIds() {}

  public static final int HARNESS = 1001,
      UPDATE = 1004,
      AGENT = 2002,
      SHELL_CONFIRM = 3003,
      DEVICE_BRIDGE = 3005,
      DATA_PROTECTION = 9031,
      RECOVERY = 9060;

  public static java.util.Set<Integer> all() {
    return java.util.Set.of(
        HARNESS, UPDATE, AGENT, SHELL_CONFIRM, DEVICE_BRIDGE, DATA_PROTECTION, RECOVERY);
  }
}

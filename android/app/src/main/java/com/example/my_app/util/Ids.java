package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.Ids —— 全量搬码，包名适配，行为契约不变。

/** Persisted transaction IDs keep the historical lowercase UUID wire format. */
public final class Ids {
  public static final String UUID_PATTERN =
      "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}";

  private Ids() {}

  public static boolean uuid(String value) {
    return value != null && value.matches(UUID_PATTERN);
  }
}

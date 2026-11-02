package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.AppIdentity —— 全量搬码，包名适配，行为契约不变。

/** Product identity for the production application. */
public final class AppIdentity {
  private AppIdentity() {}

  public static String applicationId() {
    return "dsh.android.client";
  }

  public static String displayName() {
    return "DSHA";
  }

  public static String publicDirectoryName() {
    return "DSHA";
  }

  public static String defaultUpdateFeed() {
    return "";
  }

  public static boolean isExperimental() {
    return false;
  }
}

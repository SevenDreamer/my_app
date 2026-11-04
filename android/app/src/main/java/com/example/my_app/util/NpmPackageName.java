package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.NpmPackageName —— 全量搬码，包名适配，行为契约不变。

/** Archive metadata accepts historical casing, with one bounded path-safe validation. */
public final class NpmPackageName {
  private NpmPackageName() {}

  public static boolean validArchive(String value) {
    if (value == null
        || value.length() > 214
        || value.contains("..")
        || !value.matches("(?:@[A-Za-z0-9._-]+/)?[A-Za-z0-9._-]+")) return false;
    String leaf = value.substring(value.lastIndexOf('/') + 1);
    return !leaf.equals(".") && !value.startsWith("@./");
  }
}

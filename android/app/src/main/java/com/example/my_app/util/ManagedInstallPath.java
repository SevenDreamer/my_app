package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ManagedInstallPath —— 全量搬码，包名适配，行为契约不变。

/** Canonical relative spelling for paths in the signed runtime installation recipe. */
public final class ManagedInstallPath {
  private ManagedInstallPath() {}

  public static boolean valid(String value) {
    if (value == null
        || value.isEmpty()
        || value.startsWith("/")
        || value.indexOf('\\') >= 0
        || value.indexOf(':') >= 0
        || value.indexOf('\0') >= 0) return false;
    for (String part : value.split("/", -1))
      if (part.isEmpty() || part.equals(".") || part.equals("..")) return false;
    return true;
  }
}

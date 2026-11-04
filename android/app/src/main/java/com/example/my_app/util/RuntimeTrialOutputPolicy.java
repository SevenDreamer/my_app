package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.RuntimeTrialOutputPolicy —— 全量搬码，包名适配，行为契约不变。

/** 隔离试运行只把本轮自有检查插件的 loader 故障当成检查插件故障。 */
public final class RuntimeTrialOutputPolicy {
  private RuntimeTrialOutputPolicy() {}

  private static final java.util.regex.Pattern OWNED_FAILURE =
      java.util.regex.Pattern.compile(
          "^(?:Error: )?failed to (?:apply|import) loader entry [A-Za-z0-9_-]{1,80} \\(dsha-runtime-check\\):[^\\r\\n]*$");

  public static boolean ownedPluginFailure(String line) {
    if (line == null) return false;
    String plain = line.replaceAll("\\u001b\\[[0-9;]*m", "").trim();
    return OWNED_FAILURE.matcher(plain).matches();
  }
}

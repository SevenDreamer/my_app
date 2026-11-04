package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ConfigInput —— 全量搬码，包名适配，行为契约不变。

/** 配置输入先整体校验，再写入，避免一半保存或静默改成另一个值。 */
public final class ConfigInput {
  private ConfigInput() {}

  public static int port(String value) {
    int port = number(value, com.example.my_app.util.UiText.text("端口请输入 1—65535 的整数"));
    if (port < 1 || port > 65535)
      throw new IllegalArgumentException(
          com.example.my_app.util.UiText.text("端口请输入 1—65535 的整数"));
    if (port == Constants.LAN_BRIDGE_PORT || port == Constants.SHELL_BRIDGE_PORT)
      throw new IllegalArgumentException(
          com.example.my_app.util.UiText.text("3081 和 3090 已用于 App 桥接，请换一个端口"));
    return port;
  }

  private static int number(String value, String error) {
    try {
      return Integer.parseInt(value == null ? "" : value.trim());
    } catch (NumberFormatException e) {
      throw new IllegalArgumentException(error);
    }
  }
}

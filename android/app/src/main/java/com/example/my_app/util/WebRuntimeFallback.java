package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.WebRuntimeFallback —— 全量搬码，包名适配，行为契约不变。

/** 兼容重试只由已确认的进程退出触发；等待时间、插件报错和用户停止都不能触发。 */
public final class WebRuntimeFallback {
  private WebRuntimeFallback() {}

  public static boolean shouldRetry(
      String runtime,
      boolean retried,
      boolean hadAuth,
      boolean pluginFailure,
      boolean current,
      Integer exitCode) {
    return "proroot".equals(runtime)
        && !retried
        && !hadAuth
        && !pluginFailure
        && current
        && exitCode != null;
  }
}

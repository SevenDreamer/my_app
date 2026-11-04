package com.example.my_app.runtime;

// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.GuestCommandOutput —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.util.BoundedProcessRunner;
import com.example.my_app.util.UiText;

/** 历史文本 API 的显示边界；有类型调用仍区分退出码与超时。 */
final class GuestCommandOutput {
  static String legacy(BoundedProcessRunner.Result result, long timeoutMs) {
    if (result.timedOut) return UiText.format("ERROR: 命令执行超时（%s 秒），已请求停止本次进程", timeoutMs / 1000);
    return result.output;
  }

  private GuestCommandOutput() {}
}

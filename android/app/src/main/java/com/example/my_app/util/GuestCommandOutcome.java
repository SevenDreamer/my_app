package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.GuestCommandOutcome —— 全量搬码，包名适配，行为契约不变。

import java.io.IOException;

/** Require a real completed guest command before interpreting its output as proof. */
public final class GuestCommandOutcome {
  private GuestCommandOutcome() {}

  public static String requireCompleted(BoundedProcessRunner.Result result, String phase)
      throws IOException {
    if (result == null) throw new IOException(phase + "_NO_RESULT");
    if (result.timedOut) throw new IOException(phase + "_TIMEOUT: " + detail(result));
    if (result.exitCode != 0)
      throw new IOException(phase + "_EXIT_" + result.exitCode + ": " + detail(result));
    if (result.truncated) throw new IOException(phase + "_OUTPUT_TRUNCATED: " + detail(result));
    return result.output;
  }

  private static String detail(BoundedProcessRunner.Result result) {
    String tail = result.tail.isEmpty() ? result.output : result.tail;
    if (tail.length() > 1200) tail = tail.substring(tail.length() - 1200);
    return "exit="
        + result.exitCode
        + " timedOut="
        + result.timedOut
        + " truncated="
        + result.truncated
        + " output="
        + SensitiveData.redact(tail);
  }
}

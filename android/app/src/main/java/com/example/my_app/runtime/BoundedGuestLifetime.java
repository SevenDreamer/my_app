package com.example.my_app.runtime;

// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.BoundedGuestLifetime —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.util.ProcessTermination;
import com.example.my_app.util.RuntimeWorkPort;

/** Close an owned guest session before interpreting an early foreground status as full exit. */
final class BoundedGuestLifetime {
  private BoundedGuestLifetime() {}

  static void finish(
      Process process,
      Runnable closeSession,
      Runnable onCloseFailure,
      RuntimeWorkPort.Work work,
      Throwable original) {
    RuntimeException closeFailure = null;
    try {
      if (closeSession != null) closeSession.run();
    } catch (RuntimeException failure) {
      closeFailure = failure;
      if (onCloseFailure != null) onCloseFailure.run();
    }
    try {
      if (process != null && !ProcessTermination.exited(process)) work.retainUntilExit(process);
      else work.close();
    } finally {
      if (closeFailure != null) {
        if (original != null) original.addSuppressed(closeFailure);
        else throw closeFailure;
      }
    }
  }
}

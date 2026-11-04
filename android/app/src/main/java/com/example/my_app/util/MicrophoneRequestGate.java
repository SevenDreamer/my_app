package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.MicrophoneRequestGate —— 全量搬码，包名适配，行为契约不变。

/** 页面取消只撤销授权，不提前复用仍在等系统结果的槽位。 */
public final class MicrophoneRequestGate {
  private long next, active;
  private boolean cancelled;

  public synchronized long begin() {
    if (active != 0) return -1;
    active = ++next;
    cancelled = false;
    return active;
  }

  public synchronized void cancel() {
    if (active != 0) cancelled = true;
  }

  public synchronized boolean resolve(long ticket, boolean granted, boolean current) {
    if (ticket <= 0 || ticket != active) return false;
    boolean result = granted && current && !cancelled;
    active = 0;
    cancelled = false;
    return result;
  }
}

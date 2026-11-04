package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.ApplicationServiceSlot —— 全量搬码，包名适配，行为契约不变。

/** One application service reference; a destroyed predecessor cannot detach its replacement. */
public final class ApplicationServiceSlot<T> {
  private T value;

  public synchronized void attach(T service) {
    value = java.util.Objects.requireNonNull(service);
  }

  public synchronized T current() {
    return value;
  }

  public synchronized void release(T service) {
    if (value == service) value = null;
  }
}

package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenLifecycleState —— 全量搬码，包名适配，行为契约不变。

/** 本机授权失效与远端退出分开表示；三个未知状态都禁止重新派发启动。 */
public enum VirtualScreenLifecycleState {
  STOPPED,
  STARTING,
  READY,
  START_UNKNOWN,
  DISCONNECTED,
  CLOSING,
  CLOSE_UNKNOWN;

  public boolean cleanupPending() {
    return this == START_UNKNOWN
        || this == DISCONNECTED
        || this == CLOSING
        || this == CLOSE_UNKNOWN;
  }
}

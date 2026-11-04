package com.example.my_app;

// 终端会话属主 stub（原版依赖 termux——终端功能后置）。
// closeAllAndConfirm：无会话时即刻确认关闭（行为中性）。
public final class TerminalSessionOwner {
  private static final TerminalSessionOwner INSTANCE = new TerminalSessionOwner();

  private TerminalSessionOwner() {}

  public static TerminalSessionOwner shared() {
    return INSTANCE;
  }

  public boolean closeAllAndConfirm(long timeoutMs) {
    return true;
  }
}

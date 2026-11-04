package com.example.my_app.core;

// 终端会话属主 stub（终端功能后置；会话语义中性）。
public final class TerminalSessionOwner {
  private static final TerminalSessionOwner INSTANCE = new TerminalSessionOwner();
  private TerminalSessionOwner() {}
  public static TerminalSessionOwner shared() { return INSTANCE; }
  public boolean closeAllAndConfirm(long timeoutMs) { return true; }
  public boolean isOwner(Object session) { return false; }
  public boolean isExclusive(Object session) { return false; }
  public void remove(Object session) {}
}

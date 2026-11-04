package com.example.my_app.ui;

// 终端页空壳（termux 依赖豁免、终端功能后置）：保宿主装配编译语义。
public class TerminalFragment extends androidx.fragment.app.Fragment {
  public TerminalFragment() {}

  public static boolean preferred(android.content.Context context) {
    return false;
  }

  public static void shutdownShell() {}
}

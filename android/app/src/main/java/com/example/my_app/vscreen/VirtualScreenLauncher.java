package com.example.my_app.vscreen;

// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenLauncher —— 全量搬码，包名适配，行为契约不变。

import android.content.Context;
import com.example.my_app.util.ShellQuote;
import com.example.my_app.util.VirtualScreenCoreIdentity;
import com.example.my_app.util.VirtualScreenHandshake;

/** 只生成当前安装包的受限启动/只读退出探针，不接受任意 shell。 */
final class VirtualScreenLauncher {
  private static String prefix(Context app) {
    return "/system/bin/app_process "
        + ShellQuote.arg("-Djava.class.path=" + app.getApplicationInfo().sourceDir)
        + " /system/bin com.example.my_app.vscreen.VirtualScreenCore ";
  }

  String launchCommand(Context app) {
    return prefix(app) + "--launch --port 0 --package " + ShellQuote.arg(app.getPackageName());
  }

  String probeCommand(Context app, VirtualScreenCoreIdentity identity) {
    return prefix(app)
        + "--probe-exit --identity "
        + ShellQuote.arg(identity.encode())
        + " --package "
        + ShellQuote.arg(app.getPackageName());
  }

  VirtualScreenHandshake parse(String result) {
    return VirtualScreenHandshake.started(result);
  }
}

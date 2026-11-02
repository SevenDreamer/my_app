package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.DshEntrypoint —— 全量搬码，包名适配，行为契约不变。

/** 主启动和命令行共享包内入口，Node 的 ESM 查找不能依赖全局 bin 软链。 */
public final class DshEntrypoint {
  public static final String NODE = "/usr/local/bin/node";
  public static final String SCRIPT = "/usr/local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js";

  private DshEntrypoint() {}

  public static String exec() {
    return "exec " + NODE + " " + SCRIPT;
  }

  public static String wrapper() {
    return "#!/bin/sh\n" + exec() + " \"$@\"\n";
  }
}

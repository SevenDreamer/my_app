package com.example.my_app.runtime;

import java.io.IOException;

// 终端运行时 stub（原版依赖 termux terminal-view——公共仓无件且 GPL 传染，
// 终端功能后置）。仅满足 ProotBootstrap 编译契约。
public final class TerminalRuntime {
  public TerminalRuntime(Object context, Object rootfsDir, Object execution, Object hostPorts) {}

  public Launch launch(String... guestCommand) {
    return new Launch(new String[0], new String[0]);
  }

  public Process interactive() throws IOException {
    throw new IOException("TERMINAL_RUNTIME_UNAVAILABLE");
  }

  public static final class Launch {
    private final String[] argv, environment;
    public Launch(String[] argv, String[] environment) {
      this.argv = argv; this.environment = environment;
    }
    public String[] argv() { return argv; }
    public String[] environment() { return environment; }
  }
}

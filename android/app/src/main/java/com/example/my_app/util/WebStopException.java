package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.WebStopException —— 全量搬码，包名适配，行为契约不变。

import java.io.IOException;

/** 内核或记录检查的类型化异常；getMessage 不保存任何界面语言。 */
public final class WebStopException extends IOException {
  private final WebStopDiagnostic diagnostic;

  public WebStopException(WebStopDiagnostic.Code code, Object... arguments) {
    this(WebStopDiagnostic.of(code, arguments), null);
  }

  public WebStopException(WebStopDiagnostic.Code code, Throwable cause, Object... arguments) {
    this(WebStopDiagnostic.of(code, arguments), cause);
  }

  public WebStopException(WebStopDiagnostic diagnostic, Throwable cause) {
    super(diagnostic.debug(), cause);
    this.diagnostic = diagnostic;
  }

  public WebStopDiagnostic diagnostic() {
    return diagnostic;
  }
}

package com.example.my_app.runtime;

// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.GuestPreparationFailure —— 全量搬码，包名适配，行为契约不变。

import java.io.IOException;

/** Typed preparation failures; legacy text adapters keep their historic public codes. */
final class GuestPreparationFailure extends IOException {
  enum Code {
    ENV_NOT_READY,
    BUNDLED_PYTHON_UNAVAILABLE
  }

  final Code code;

  GuestPreparationFailure(Code code) {
    super(code.name());
    this.code = code;
  }

  static boolean is(Throwable error, Code code) {
    return error instanceof GuestPreparationFailure
        && ((GuestPreparationFailure) error).code == code;
  }
}

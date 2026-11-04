package com.example.my_app.capabilities;

// 版权来源：DSHA（MIT）com.deepseekharness.app.capabilities.WindowTargetEvidence —— 全量搬码，包名适配，行为契约不变。

/** A selected Android window. Implementations can additionally bind pixel or semantic evidence. */
public interface WindowTargetEvidence extends TargetEvidence {
  int displayId();

  int windowId();

  String packageName();
}

package com.example.my_app.capabilities;

// 版权来源：DSHA（MIT）com.deepseekharness.app.capabilities.TargetEvidence —— 全量搬码，包名适配，行为契约不变。

/** Immutable evidence captured by an adapter. Evidence is never itself an execution permission. */
public interface TargetEvidence {
  String kind();
}

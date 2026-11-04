package com.example.my_app.core;

// 版权来源：DSHA（MIT）com.deepseekharness.app.core.WebRecovery —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.util.RestartBudget;
import com.example.my_app.util.SensitiveData;

/** 保存恢复状态；所有调用由 Controller 的生命周期锁串行化。 */
final class WebRecovery {
  private final ConfigStore config;
  private final RestartBudget budget;
  private long generation;
  private String stage = com.example.my_app.util.UiText.text("服务健康检查");

  WebRecovery(ConfigStore config) {
    this.config = config;
    budget = new RestartBudget(config.getWebFailures());
  }

  void begin(long next, boolean manual) {
    generation = next;
    budget.begin(next, manual);
    stage = com.example.my_app.util.UiText.text("准备运行环境");
    if (manual) config.recordWebRecovery(0, "", "");
  }

  void stage(long expected, String value) {
    if (generation == expected) stage = value;
  }

  boolean fail(long expected, String reason) {
    if (!budget.fail(expected)) return false;
    config.recordWebRecovery(budget.failures(), stage, SensitiveData.redact(reason));
    return true;
  }

  void healthy(long expected, long now) {
    if (budget.healthy(expected, now)) config.recordWebRecovery(0, "", "");
  }

  void unhealthy(long expected) {
    budget.unhealthy(expected);
  }

  boolean blocked() {
    return budget.blocked();
  }

  boolean failed(long expected) {
    return budget.failed(expected);
  }
}

package com.example.my_app.bridge;

// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.AppLaunchTargetEvidence —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.capabilities.TargetEvidence;
import com.example.my_app.util.ScreenConfirmationPolicy;

/** 启动许可绑定实际完整包名，不从动作描述或当前前台应用猜测。 */
public final class AppLaunchTargetEvidence implements TargetEvidence {
  public final String packageName;

  public AppLaunchTargetEvidence(String packageName) {
    if (!ScreenConfirmationPolicy.validPackage(packageName))
      throw new IllegalArgumentException("INVALID_APPLICATION_TARGET");
    this.packageName = packageName;
  }

  @Override
  public String kind() {
    return "android-application-launch";
  }
}

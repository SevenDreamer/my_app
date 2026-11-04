package com.example.my_app.core;

// 版权来源：DSHA（MIT）com.deepseekharness.app.core.EnvironmentAccess —— 全量搬码，包名适配，行为契约不变。

/** 主界面与执行入口共用恢复状态；进入界面不会写入环境就绪标记。 */
public final class EnvironmentAccess {
  private EnvironmentAccess() {}

  public static boolean needsRecovery(HarnessController controller) {
    return !controller.isEnvironmentReady()
        || com.example.my_app.core.MaintenanceCoordinator.pending(controller);
  }

  public static boolean runtimeLatest(HarnessController controller) {
    try {
      var installed = controller.proot().installedRuntimeDescriptor();
      return installed != null && installed.latest(controller.proot().expectedRuntimeDescriptor());
    } catch (java.io.IOException error) {
      return false;
    }
  }

  /** 返回 true 时启动前必须进入维护；新候选只自动尝试一次，健康兼容前代仍可使用。 */
  public static boolean requiresMaintenanceBeforeStart(HarnessController controller) {
    if (runtimeLatest(controller)) return false;
    try {
      String candidate = "runtime:" + controller.proot().expectedRuntimeDescriptor().id();
      return com.example.my_app.util.EnvironmentIdentity.shouldBlockRuntimeStart(
          false,
          true,
          com.example.my_app.core.MaintenanceCoordinator.isEnvironmentTaskBusy(),
          com.example.my_app.core.MaintenanceCoordinator.pending(controller),
          candidate,
          controller
              .context()
              .getSharedPreferences(
                  "dsha_environment_upgrade", android.content.Context.MODE_PRIVATE)
              .getString("attempted_identity", ""));
    } catch (java.io.IOException error) {
      // 不能认证 APK 自带的运行时描述时，不得由 START_STICKY/看门狗启动旧 Web。
      return com.example.my_app.util.EnvironmentIdentity.shouldBlockRuntimeStart(
          false, false, false, false, "", "");
    }
  }
}

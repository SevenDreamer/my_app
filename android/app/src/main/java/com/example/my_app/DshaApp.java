package com.example.my_app;

// 版权来源：DSHA（MIT）com.deepseekharness.app.DshaApp —— 全量搬码，包名适配，行为契约不变。

import android.app.Application;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;

/**
 * 应用入口：全局初始化。
 * 骨架阶段只建一个任务通知渠道；完整版另有配对/确认渠道（见原 Constants.CHANNEL_*）。
 */
public class DshaApp extends Application
    implements com.example.my_app.runtime.RuntimeHostPorts.Owner,
        com.example.my_app.data.PortableSettings.Owner,
        com.example.my_app.backup.MaintenanceUiPorts {

  private final com.example.my_app.capabilities.CapabilityBroker screenCapabilityBroker =
      new com.example.my_app.capabilities.CapabilityBroker(
          android.os.SystemClock::elapsedRealtime);
  private volatile String screenInstallationId;

  public com.example.my_app.capabilities.CapabilityBroker capabilityBroker() {
    return screenCapabilityBroker;
  }

  /** Local installation authority is never taken from an imported data archive. */
  public synchronized String installationId() {
    if (screenInstallationId == null) {
      try {
        screenInstallationId = com.example.my_app.core.InstallationIdentity.loadOrCreate(this);
      } catch (java.io.IOException unavailable) {
        throw new IllegalStateException("INSTALLATION_IDENTITY_UNAVAILABLE", unavailable);
      }
    }
    return screenInstallationId;
  }

  private final com.example.my_app.runtime.RuntimeHostPorts runtimeHostPorts =
      new com.example.my_app.runtime.RuntimeHostPorts();

  @Override
  public com.example.my_app.runtime.RuntimeHostPorts runtimeHostPorts() {
    return runtimeHostPorts;
  }

  @Override
  public android.content.Intent dataProtectionPage(boolean nativeBackup, long maintenanceId) {
    return nativeBackup
        ? new android.content.Intent(this, com.example.my_app.ui.NativeDataActivity.class)
        : new android.content.Intent(this, com.example.my_app.ui.ExtractActivity.class)
            .putExtra("review_only", true)
            .putExtra("data_task_id", maintenanceId);
  }

  @Override
  public android.content.Intent runtimePage() {
    return new android.content.Intent(this, com.example.my_app.ui.MainActivity.class)
        .addFlags(
            android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                | android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                | android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
        .putExtra("open_launch", true);
  }

  private final com.example.my_app.util.ApplicationServiceSlot<HarnessService> harnessService =
      new com.example.my_app.util.ApplicationServiceSlot<>();

  public com.example.my_app.util.ApplicationServiceSlot<HarnessService> harnessService() {
    return harnessService;
  }

  private final com.example.my_app.core.HarnessSessionState harnessSession =
      new com.example.my_app.core.HarnessSessionState();
  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.core.HarnessController>
      harnessOwner = new com.example.my_app.util.ApplicationOwner<>();

  /** Legacy controller facades share the application's queue, process records and generation. */
  public com.example.my_app.core.HarnessSessionState harnessSession() {
    return harnessSession;
  }

  public com.example.my_app.core.HarnessController harnessController() {
    return harnessOwner.get(() -> new com.example.my_app.core.HarnessController(this));
  }

  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.core.BackupTask>
      backupOwner = new com.example.my_app.util.ApplicationOwner<>();
  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.core.InstallRepository>
      installOwner = new com.example.my_app.util.ApplicationOwner<>();
  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.core.PluginRepository>
      pluginOwner = new com.example.my_app.util.ApplicationOwner<>();
  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.vscreen.VirtualScreenManager>
      virtualScreenOwner = new com.example.my_app.util.ApplicationOwner<>();
  private final com.example.my_app.util.ApplicationOwner<
          com.example.my_app.data.PortableSettings>
      portableSettingsOwner = new com.example.my_app.util.ApplicationOwner<>();

  public com.example.my_app.core.BackupTask backupTask() {
    return backupOwner.get(() -> new com.example.my_app.core.BackupTask(this));
  }

  public com.example.my_app.core.InstallRepository installRepository() {
    return installOwner.get(() -> new com.example.my_app.core.InstallRepository(this));
  }

  public com.example.my_app.core.PluginRepository pluginRepository() {
    return pluginOwner.get(() -> new com.example.my_app.core.PluginRepository(this));
  }

  public com.example.my_app.vscreen.VirtualScreenManager virtualScreenManager() {
    return virtualScreenOwner.get(
        () -> new com.example.my_app.vscreen.VirtualScreenManager(this));
  }

  @Override
  public com.example.my_app.data.PortableSettings portableSettings() {
    return portableSettingsOwner.get(com.example.my_app.data.PortableSettings::new);
  }

  public static DshaApp from(android.content.Context context) {
    java.util.IdentityHashMap<android.content.Context, Boolean> seen =
        new java.util.IdentityHashMap<>();
    android.content.Context current = context;
    for (int depth = 0;
        current != null && depth < 32 && seen.put(current, Boolean.TRUE) == null;
        depth++) {
      if (current instanceof DshaApp) return (DshaApp) current;
      android.content.Context application = current.getApplicationContext();
      if (application instanceof DshaApp) return (DshaApp) application;
      if (current instanceof android.content.ContextWrapper)
        current = ((android.content.ContextWrapper) current).getBaseContext();
      else current = application == current ? null : application;
    }
    throw new IllegalStateException("DSHA_APPLICATION_SCOPE_UNAVAILABLE");
  }

  @Override
  public void onCreate() {
    super.onCreate();
    // 必须早于界面 Locale.setDefault；保留系统原始语言供「跟随系统」使用。
    com.example.my_app.util.SystemLanguage.initialize(this);
    com.example.my_app.data.PortableSettings.initialize(this);
    com.example.my_app.ui.LanguageController.apply(this);
    ShizukuShell.init(this);
    com.example.my_app.ui.ThemeController.apply(this);
    com.example.my_app.core.RuntimeTasks.initialize(this);
    final android.content.Context runtimeApp = getApplicationContext();
    runtimeHostPorts.install(
        new com.example.my_app.runtime.RuntimeHostPorts.Provider() {
          @Override
          public com.example.my_app.runtime.RuntimeHostPorts.Settings snapshot() {
            return new com.example.my_app.core.ConfigStore(runtimeApp)
                .runtimeSettingsSnapshot();
          }

          @Override
          public boolean preferFastColdMode() {
            return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                && new com.example.my_app.core.ConfigStore(runtimeApp).preferFastColdMode();
          }

          @Override
          public void stage(String value) {
            com.example.my_app.core.ColdInstallDiagnostics.stage(runtimeApp, value);
          }

          @Override
          public void record(String kind, String detail) {
            com.example.my_app.core.ColdInstallDiagnostics.record(runtimeApp, kind, detail);
          }

          @Override
          public void failure(Throwable error) {
            com.example.my_app.core.ColdInstallDiagnostics.failure(runtimeApp, error);
          }

          @Override
          public String describeWebStop(com.example.my_app.util.WebStopDiagnostic diagnostic) {
            return com.example.my_app.core.WebStopText.render(diagnostic);
          }

          @Override
          public com.example.my_app.runtime.RuntimeTrial.BrowserProbe browserProbe() {
            return com.example.my_app.ui.RuntimeBrowserProbe::open;
          }

          @Override
          public java.util.Map<String, Object> snapshotColdSelection() throws java.io.IOException {
            return new com.example.my_app.core.ConfigStore(runtimeApp)
                .snapshotColdRuntimeSelection();
          }

          @Override
          public void restoreColdSelection(
              java.util.Map<String, Object> before, String expectedRoot)
              throws java.io.IOException {
            new com.example.my_app.core.ConfigStore(runtimeApp)
                .restoreColdRuntimeSelection(before, expectedRoot);
          }

          @Override
          public String coldRuntimeIdentity(java.io.File rootfs) throws java.io.IOException {
            return checkedColdRuntimeIdentity(runtimeApp, rootfs);
          }

          @Override
          public com.example.my_app.runtime.RuntimeHostPorts.Settings successfulColdRuntime(
              java.io.File rootfs,
              com.example.my_app.util.ColdInstallPlan.Mode mode,
              String packageSlotSha)
              throws java.io.IOException {
            String rootIdentity = checkedColdRuntimeIdentity(runtimeApp, rootfs);
            java.io.File current =
                new java.io.File(runtimeApp.getFilesDir(), "linux/ubuntu").getCanonicalFile();
            var fs = new com.example.my_app.backup.AndroidBackupFileSystem();
            java.io.File toolsVersion =
                new java.io.File(current, "root/.dsha-ubuntu-tools-version");
            if (!fs.stat(toolsVersion).type.equals("FILE")
                || !new String(
                        fs.small(toolsVersion, 128), java.nio.charset.StandardCharsets.US_ASCII)
                    .matches("[a-f0-9]{64}\\n"))
              throw new java.io.IOException("COLD_RUNTIME_POSTCHECK_MISSING");
            var selected =
                new com.example.my_app.core.ConfigStore(runtimeApp)
                    .recordSuccessfulColdRuntime(mode, rootIdentity, packageSlotSha);
            com.example.my_app.core.ColdInstallDiagnostics.record(
                runtimeApp,
                "RUNTIME_SELECTED",
                "runtime="
                    + mode.runtime
                    + " prootNoSeccomp="
                    + mode.noSeccomp
                    + " packageSlotSha256="
                    + packageSlotSha);
            return selected;
          }
        });
    com.example.my_app.backup.AutomaticBackups.schedule(this);
    com.example.my_app.backup.PostUpgradeCleanupService.schedule(this);
    com.example.my_app.core.DiagnosticLog.installCrashHandler(this);
    registerActivityLifecycleCallbacks(new com.example.my_app.ui.ModernAndroidUi());
    registerActivityLifecycleCallbacks(new ForegroundActivity());
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      NotificationManager nm = getSystemService(NotificationManager.class);
      nm.createNotificationChannel(
          new NotificationChannel(
              "dsh_task_channel",
              com.example.my_app.util.UiText.text("任务通知"),
              NotificationManager.IMPORTANCE_LOW));
    }
  }

  private static String checkedColdRuntimeIdentity(android.content.Context app, java.io.File rootfs)
      throws java.io.IOException {
    var fs = new com.example.my_app.backup.AndroidBackupFileSystem();
    java.io.File current = fs.child(app.getFilesDir().getCanonicalFile(), "linux/ubuntu");
    var node = fs.stat(current);
    if (!node.type.equals("DIRECTORY")
        || !current.getCanonicalFile().equals(rootfs.getCanonicalFile()))
      throw new java.io.IOException("COLD_RUNTIME_ROOT_CHANGED");
    return current.getCanonicalPath() + ":" + node.device + ":" + node.key;
  }
}

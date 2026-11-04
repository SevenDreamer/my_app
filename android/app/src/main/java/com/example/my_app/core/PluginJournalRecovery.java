package com.example.my_app.core;

// 版权来源：DSHA（MIT）com.deepseekharness.app.core.PluginJournalRecovery —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.backup.AndroidBackupFileSystem;
import com.example.my_app.backup.BackupJson;
import com.example.my_app.backup.PluginInstallJournals;
import com.example.my_app.backup.UserDataLayout;
import com.example.my_app.util.FileKind;
import com.example.my_app.util.GuestCommandOutcome;
import com.example.my_app.util.PluginOutput;
import com.example.my_app.util.ShellQuote;
import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/** Host coordination of guest plugin recovery; the backup journal itself only manages records. */
public final class PluginJournalRecovery {
  private PluginJournalRecovery() {}

  public static String recover(HarnessController controller) throws Exception {
    if (!MaintenanceCoordinator.isOwner() || RuntimeTasks.hasOtherTasks())
      throw new IOException("PLUGIN_RECOVERY_REQUIRES_MAINTENANCE");
    controller.proot().ensureRuntimeFiles();
    var fs = new AndroidBackupFileSystem();
    String id = UUID.randomUUID().toString();
    File root = controller.proot().getRootfsDir().getCanonicalFile();
    File proof = new File(root, "root/.dsha-plugin-recovery-" + id);
    try {
      try (OutputStream output = fs.create(proof)) {
        output.write("RECOVER_PLUGIN_OPERATIONS".getBytes(StandardCharsets.US_ASCII));
      }
      String text =
          GuestCommandOutcome.requireCompleted(
              controller
                  .proot()
                  .execAndReadWithProotResult(
                      "python3 /root/.dsh/plugin-manager.py recover-installs " + ShellQuote.arg(id),
                      120000),
              "PLUGIN_RECOVERY");
      var result =
          BackupJson.read(
              PluginOutput.resultJson(text).getBytes(StandardCharsets.UTF_8), 1024 * 1024);
      if (!"ok".equals(result.get("status"))) {
        Object message = result.get("message");
        throw new IOException(
            message instanceof String ? (String) message : "PLUGIN_RECOVERY_FAILED");
      }
      PluginInstallJournals.archiveCompleted(
          fs,
          new UserDataLayout(fs, root.getParentFile().getParentFile().getCanonicalFile())
              .current());
      return com.example.my_app.util.UiText.text("中断的插件操作已恢复，旧版本、依赖与失败候选均保留。");
    } finally {
      if (fs.stat(proof).kind != FileKind.MISSING) fs.delete(proof);
    }
  }
}

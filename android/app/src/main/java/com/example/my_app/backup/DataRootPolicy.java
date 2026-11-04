package com.example.my_app.backup;

// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.DataRootPolicy —— 全量搬码，包名适配，行为契约不变。

import com.example.my_app.util.ManagedRuntimeLayout;
import java.util.*;

/** 本机状态不从用户归档恢复；可执行配置/受管工具只能导入隔离区，不覆盖活跃入口。 */
public final class DataRootPolicy {
  private DataRootPolicy() {}

  public static boolean machine(String name) {
    return com.example.my_app.util.CredentialPaths.backupMachine(name);
  }

  public static String exclusion(String rootName, String relative) {
    if (machine(rootName)) return "DEVICE_SPECIFIC_STATE";
    if (relative != null)
      for (String part : relative.split("/"))
        if (com.example.my_app.util.CredentialPaths.machine(part))
          return "DEVICE_SPECIFIC_STATE";
    if (com.example.my_app.util.CredentialPaths.sessionTrash(rootName, relative))
      return "RETAINED_SESSION_TRASH";
    return "";
  }

  public static boolean directData(String name) {
    return Set.of(
            "sessions",
            "storages",
            "attachments",
            "settings.yaml",
            ".credentials.yaml",
            ".env",
            ".dsha-apikey")
        .contains(name);
  }

  public static boolean quarantineCode(String name) {
    return name.equals("cordis.patch.yml")
        || ManagedRuntimeLayout.paths().contains("root/.dsh/" + name)
        || name.matches(".*\\.(?:js|cjs|mjs|py|sh)");
  }
}

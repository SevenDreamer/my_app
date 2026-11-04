package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.BackupScopes —— 全量搬码，包名适配，行为契约不变。

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/** Host v5 scope names; legacy full/sessions integer encodings remain in BackupScope. */
public final class BackupScopes {
  public static final String APPLICATION = "application",
      SESSIONS = "sessions",
      SETTINGS = "settings",
      PLUGINS = "plugins",
      PROJECTS = "projects";
  public static final List<String> ORDERED =
      List.of(APPLICATION, SESSIONS, SETTINGS, PLUGINS, PROJECTS);
  public static final Set<String> ALL = Collections.unmodifiableSet(new LinkedHashSet<>(ORDERED));

  private BackupScopes() {}
}

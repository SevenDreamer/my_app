package com.example.my_app.backup;

// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.MaintenanceUiPorts —— 全量搬码，包名适配，行为契约不变。

import android.content.Intent;

/** The application composition root supplies notification destinations to data services. */
public interface MaintenanceUiPorts {
  Intent dataProtectionPage(boolean nativeBackup, long maintenanceId);

  Intent runtimePage();

  static MaintenanceUiPorts fromOwner(Object owner) {
    if (!(owner instanceof MaintenanceUiPorts))
      throw new IllegalStateException("MAINTENANCE_UI_OWNER_UNAVAILABLE");
    return (MaintenanceUiPorts) owner;
  }
}

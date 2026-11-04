package com.example.my_app.core;

// 版权来源：DSHA（MIT）com.deepseekharness.app.core.InstallationIdentity —— 全量搬码，包名适配，行为契约不变。

import android.content.Context;
import com.example.my_app.backup.AndroidBackupFileSystem;
import com.example.my_app.util.AppInstallIdentity;
import com.example.my_app.util.ColdInstallPackages;
import java.io.File;
import java.io.IOException;

/** API23-safe application identity storage: anchored lstat/O_EXCL/NOFOLLOW, 0600 and fsync. */
public final class InstallationIdentity {
  private InstallationIdentity() {}

  public static String loadOrCreate(Context context) throws IOException {
    var fs = new AndroidBackupFileSystem();
    var host =
        ColdInstallPackages.bindPrivateFiles(
            fs, new File(context.getApplicationInfo().dataDir), context.getFilesDir());
    String id = AppInstallIdentity.loadOrCreate(fs, host.files);
    host.verify(fs);
    return id;
  }
}

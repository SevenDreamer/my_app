package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.BundledRootfsAsset —— 全量搬码，包名适配，行为契约不变。

import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/** The current signed APK has one rootfs asset; historical backups have separate readers. */
public final class BundledRootfsAsset {
  public static final String NAME = "offline-rootfs.bin";

  private BundledRootfsAsset() {}

  public static ZipEntry find(ZipFile apk) {
    ZipEntry entry = apk.getEntry("assets/" + NAME);
    return entry != null && !entry.isDirectory() ? entry : null;
  }
}

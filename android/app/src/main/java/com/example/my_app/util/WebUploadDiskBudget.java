package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.WebUploadDiskBudget —— 全量搬码，包名适配，行为契约不变。

import java.io.IOException;
import java.util.function.LongSupplier;

/** 同一宿主缓存卷的检查与写入串行；不在这里等待或读取远端 Provider。 */
public final class WebUploadDiskBudget {
  public interface Write {
    void run() throws IOException;
  }

  public synchronized void write(long nextBytes, LongSupplier usableSpace, Write write)
      throws IOException {
    WebTransferPolicy.checkUploadSpace(nextBytes, usableSpace.getAsLong());
    write.run();
  }
}

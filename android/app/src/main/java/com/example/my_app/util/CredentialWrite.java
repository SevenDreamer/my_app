package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.CredentialWrite —— 全量搬码，包名适配，行为契约不变。

import java.io.IOException;

/** 保存和恢复共用的凭据写入准备；读回失败时不向调用方交付可提交密文。 */
public final class CredentialWrite {
  private CredentialWrite() {}

  public interface Encrypt {
    String apply(String value);
  }

  public interface Read {
    CredentialRead apply(String encrypted);
  }

  public static String prepare(String value, Encrypt encrypt, Read read) throws IOException {
    String plain = value == null ? "" : value;
    if (plain.length() > 16384) throw new IOException("CREDENTIAL_LIMIT");
    if (plain.isEmpty()) return "";
    String encrypted = encrypt.apply(plain);
    if (encrypted == null || encrypted.isEmpty())
      throw new IOException("CREDENTIAL_ENCRYPTION_FAILED");
    CredentialRead verified = read.apply(encrypted);
    if (verified == null || verified.state != CredentialRead.State.AVAILABLE)
      throw new IOException("CREDENTIAL_READBACK_UNAVAILABLE");
    if (!plain.equals(verified.requireValue()))
      throw new IOException("CREDENTIAL_READBACK_MISMATCH");
    return encrypted;
  }
}

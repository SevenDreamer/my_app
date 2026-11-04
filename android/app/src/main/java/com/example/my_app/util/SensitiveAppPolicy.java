package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.SensitiveAppPolicy —— 全量搬码，包名适配，行为契约不变。

import java.util.Locale;

/** A conservative classification aid, never a proof that an app or screen is harmless. */
public final class SensitiveAppPolicy {
  private SensitiveAppPolicy() {}

  public static boolean sensitive(String pkg) {
    if (pkg == null || pkg.isEmpty()) return true;
    String p = pkg.toLowerCase(Locale.ROOT);
    for (String key :
        new String[] {
          "alipay",
          "tencent.mm",
          "unionpay",
          "jdpay",
          "wallet",
          "paypal",
          "bank",
          "icbc",
          "ccb",
          "abchina",
          "bankofchina",
          "cmbchina",
          "bankcomm",
          "psbc",
          "cebbank",
          "cmbc",
          "spdb",
          "citic",
          "hxb",
          "keepass",
          "bitwarden",
          "lastpass",
          "1password",
          "authenticator",
          "com.android.settings",
          "com.android.systemui",
          "telephony",
          "messaging",
          "sms",
          "securities",
          "broker",
          "trading"
        }) if (p.contains(key)) return true;
    return false;
  }
}

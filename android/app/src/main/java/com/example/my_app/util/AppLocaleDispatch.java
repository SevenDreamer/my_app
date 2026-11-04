package com.example.my_app.util;

// 版权来源：DSHA（MIT）com.deepseekharness.app.util.AppLocaleDispatch —— 全量搬码，包名适配，行为契约不变。

/** Select the platform locale writer before Activity delegates exist on Android 13+. */
public final class AppLocaleDispatch {
  private AppLocaleDispatch() {}

  public interface Writer {
    void platform(String language);

    void compat(String language);
  }

  public static void apply(int sdk, String language, Writer writer) {
    if (!"zh".equals(language) && !"en".equals(language))
      throw new IllegalArgumentException("UI_LANGUAGE");
    if (sdk >= 33) writer.platform(language);
    else writer.compat(language);
  }
}

package com.example.my_app.vscreen;

// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenJournal —— 全量搬码，包名适配，行为契约不变。

import org.json.JSONObject;

/** API23-safe journal contract; its NIO implementation is loaded only by the API30 factory. */
interface VirtualScreenJournal {
  JSONObject load() throws Exception;

  boolean save(long revision, JSONObject value) throws Exception;
}

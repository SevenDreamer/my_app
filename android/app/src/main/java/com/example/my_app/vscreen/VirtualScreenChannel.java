package com.example.my_app.vscreen;

// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenChannel —— 全量搬码，包名适配，行为契约不变。

import android.content.Context;

/** 虚拟屏核心的受管启动通道；实现不能把它退化成任意 shell。 */
public interface VirtualScreenChannel {
  String id();

  boolean available(Context context);

  String start(Context context, String command);

  /** Legacy text can carry a valid handshake, but can never prove that launch was not sent. */
  default com.example.my_app.device.DeviceTransportResult startTyped(
      Context context, String command) {
    return com.example.my_app.device.DeviceTransportResult.unknown(
        id(),
        "VSCREEN_LEGACY_START_UNCONFIRMED",
        start(context, command),
        false,
        com.example.my_app.device.DeviceTransportIdentity.unknown());
  }
}

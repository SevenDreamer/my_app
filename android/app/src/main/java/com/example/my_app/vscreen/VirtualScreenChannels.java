package com.example.my_app.vscreen;

// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenChannels —— 全量搬码，包名适配，行为契约不变。

import android.content.Context;
import com.example.my_app.DeviceBridgeService;
import com.example.my_app.RootShell;
import com.example.my_app.ShizukuShell;
import com.example.my_app.bridge.AdbBridge;

import java.util.ArrayList;
import java.util.List;

/** 复用 DSHA 的设备能力授权；结果未知时调用方不得换通道重放。 */
final class VirtualScreenChannels {
  private VirtualScreenChannels() {}

  static List<VirtualScreenChannel> all() {
    return all(android.os.Build.VERSION.SDK_INT, DeviceBridgeService.adbState);
  }

  static List<VirtualScreenChannel> all(int sdk, String adbState) {
    List<VirtualScreenChannel> channels = new ArrayList<>();
    channels.add(
        new VirtualScreenChannel() {
          public String id() {
            return "root";
          }

          public boolean available(Context c) {
            return RootShell.enabled(c) && RootShell.present();
          }

          public String start(Context c, String command) {
            return RootShell.execVirtualScreen(c, command);
          }

          public com.example.my_app.device.DeviceTransportResult startTyped(
              Context c, String command) {
            return RootShell.execVirtualScreenTyped(c, command);
          }
        });
    VirtualScreenChannel shizuku =
        new VirtualScreenChannel() {
          public String id() {
            return "shizuku";
          }

          public boolean available(Context c) {
            return ShizukuShell.hasPermission();
          }

          public String start(Context c, String command) {
            return ShizukuShell.execVirtualScreen(command);
          }

          public com.example.my_app.device.DeviceTransportResult startTyped(
              Context c, String command) {
            return ShizukuShell.execVirtualScreenTyped(command);
          }
        };
    VirtualScreenChannel adb =
        new VirtualScreenChannel() {
          public String id() {
            return "adb";
          }

          public boolean available(Context c) {
            return DeviceBridgeService.isAdbEnabled(c);
          }

          public String start(Context c, String command) {
            String ticket = VirtualScreenManager.from(c).adbLaunchTicketFor(command);
            return ticket.isEmpty()
                ? "[POLICY_BLOCKED] Native virtual-screen launch ticket missing\n[EXIT=126]"
                : AdbBridge.executeVirtualScreen(c, command, ticket);
          }

          public com.example.my_app.device.DeviceTransportResult startTyped(
              Context c, String command) {
            String ticket = VirtualScreenManager.from(c).adbLaunchTicketFor(command);
            return ticket.isEmpty()
                ? com.example.my_app.device.DeviceTransportResult.unknown(
                    "adb",
                    "VSCREEN_ADB_TICKET_UNAVAILABLE",
                    "[POLICY_BLOCKED] Native virtual-screen launch ticket missing\n[EXIT=126]",
                    true,
                    com.example.my_app.device.DeviceTransportIdentity.unknown())
                : AdbBridge.executeVirtualScreenTyped(c, command, ticket);
          }
        };
    if (sdk >= 37 && "connected".equals(adbState)) {
      // Android 17 的 Shizuku 用户服务可能在进入 DSHA 前退出；保留 Root 优先，
      // 其次使用已验证连接的 ADB；available() 仍要求其显式授权开关开启。
      channels.add(adb);
      channels.add(shizuku);
    } else {
      channels.add(shizuku);
      channels.add(adb);
    }
    return channels;
  }

  static VirtualScreenChannel find(String id) {
    for (VirtualScreenChannel channel : all()) if (channel.id().equals(id)) return channel;
    return null;
  }

  static VirtualScreenChannel choose(Context context) {
    for (VirtualScreenChannel channel : all()) if (channel.available(context)) return channel;
    return null;
  }
}

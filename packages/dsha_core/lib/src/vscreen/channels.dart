// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.{VirtualScreenChannel,VirtualScreenChannels} —— 现代化重构，行为契约不变。
//! 复用 DSHA 的设备能力授权；结果未知时调用方不得换通道重放。
//! 「虚拟屏核心的受管启动通道；实现不能把它退化成任意 shell。」
library;

/// 设备传输结果（原版 `DeviceTransportResult` 数据面）。
class DeviceTransportReceipt {
  const DeviceTransportReceipt({
    required this.transport,
    required this.state,
    required this.code,
    required this.output,
    required this.localExitConfirmed,
    required this.outputComplete,
    required this.exitCode,
    required this.remoteExitConfirmed,
  });

  /// 原版 `unknown(...)` 构造。
  DeviceTransportReceipt.unknown(this.transport, this.code, this.output,
      {this.localExitConfirmed = false})
      : state = TransportState.unknown,
        outputComplete = false,
        exitCode = null,
        remoteExitConfirmed = false;

  final String transport;
  final TransportState state;
  final String code;
  final String output;
  final bool localExitConfirmed;
  final bool outputComplete;
  final int? exitCode;
  final bool remoteExitConfirmed;
}

/// 传输结果态（原版 `CapabilityResult.State` 子集）。
enum TransportState { notSent, unknown, accepted, rejected }

/// 受管启动通道（原版 `VirtualScreenChannel`）。
abstract class VscreenChannel {
  String id();

  bool available();

  String start(String command);

  /// Legacy 文本可以携带有效握手，但永远无法证明启动没有发出。
  ///
  /// 唯一签名偏移（同 awaitExit/request 惯例）：Dart 无同步 channel——
  /// 实现必须拿真实执行输出（core 握手串在里面，VscreenHandshake.started 解析源）。
  Future<DeviceTransportReceipt> startTyped(String command) async =>
      DeviceTransportReceipt.unknown(
          id(), 'VSCREEN_LEGACY_START_UNCONFIRMED', start(command),
          localExitConfirmed: false);
}

/// 通道后端缝（原版 RootShell/ShizukuShell/AdbBridge 执行面）。
abstract class ChannelBackend implements VscreenChannel {}

/// 通道编排（原版 `VirtualScreenChannels`）。
abstract final class VscreenChannels {
  /// 全部通道（原版 `all(sdk, adbState)`）：SDK 37+ 且 ADB 已连接时 ADB 优先于 Shizuku。
  static List<VscreenChannel> all(int sdk, String adbState,
      {required VscreenChannel root,
      required VscreenChannel shizuku,
      required VscreenChannel adb}) {
    // Android 17 的 Shizuku 用户服务可能在进入 DSHA 前退出；保留 Root 优先，
    // 其次使用已验证连接的 ADB；available() 仍要求其显式授权开关开启。
    return [
      root,
      if (sdk >= 37 && adbState == 'connected') ...[adb, shizuku] else ...[shizuku, adb],
    ];
  }

  static VscreenChannel? find(String id, List<VscreenChannel> channels) {
    for (final channel in channels) {
      if (channel.id() == id) return channel;
    }
    return null;
  }

  static VscreenChannel? choose(List<VscreenChannel> channels) {
    for (final channel in channels) {
      if (channel.available()) return channel;
    }
    return null;
  }
}

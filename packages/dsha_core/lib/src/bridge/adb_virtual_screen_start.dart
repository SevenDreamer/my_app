// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.AdbVirtualScreenStart —— 现代化重构，行为契约不变。
//! 原生准入，或"已关闭的 helper + 原子撤回的许可"，两者之一才能证明没有发生远端发送。
//! 错误代号契约：`VSCREEN_ADB_INVALID_TICKET`/`VSCREEN_ADB_CANCELLED_BEFORE_START`/
//! `VSCREEN_ADB_NOT_COMMITTED`/`VSCREEN_ADB_ENVIRONMENT_BUSY`/`VSCREEN_ADB_START_UNCONFIRMED`。
library;

import 'adb_bridge.dart' show HelperResult;

/// 传输结果（原版 `DeviceTransportResult` 的移植面）。
class DeviceTransportResult {
  const DeviceTransportResult._({
    required this.state,
    required this.channel,
    required this.code,
    required this.output,
  });

  /// 未发送（有证明）。
  factory DeviceTransportResult.notSent(String channel, String code, String output) =>
      DeviceTransportResult._(state: 'not_sent', channel: channel, code: code, output: output);

  /// 结果未知（可能已发送）。
  factory DeviceTransportResult.unknown(String channel, String code, String output) =>
      DeviceTransportResult._(state: 'unknown', channel: channel, code: code, output: output);

  final String state, channel, code, output;
}

/// 一次性的受管启动准入（原版 `Boundary`）。
class VscreenLaunchBoundary {
  VscreenLaunchBoundary(this._cancelled);

  final bool Function() _cancelled;
  bool helperAttempted = false;
  bool cancelledBeforeHelper = false;

  /// 只允许一次；已尝试或已取消则拒绝。
  bool enter() {
    if (helperAttempted || cancelledBeforeHelper) return false;
    if (_cancelled()) {
      cancelledBeforeHelper = true;
      return false;
    }
    helperAttempted = true;
    return true;
  }
}

/// 受管虚拟屏启动执行（原版 `executeTyped`）。
///
/// 票据由 `/device/vscreen/commit` 在唯一远端发送前一刻消费。
/// 丢失的 commit 响应、缺失票据或已提交的尝试都过不了
/// [withdrawUncommitted] 这道原子撤回——无论 stdout 说什么。
Future<DeviceTransportResult> executeVirtualScreenTyped({
  required String? ticket,
  required bool Function() cancelled,
  required String Function() cancelledOutput,
  required Future<HelperResult> Function(VscreenLaunchBoundary boundary) launch,
  required bool Function() withdrawUncommitted,
}) async {
  if (ticket == null || !RegExp(r'^[a-f0-9]{48}$').hasMatch(ticket)) {
    return DeviceTransportResult.notSent('adb', 'VSCREEN_ADB_INVALID_TICKET',
        '[POLICY_BLOCKED] Invalid native virtual-screen ticket\n[EXIT=126]');
  }
  if (cancelled()) {
    return DeviceTransportResult.notSent(
        'adb', 'VSCREEN_ADB_CANCELLED_BEFORE_START', cancelledOutput());
  }
  final boundary = VscreenLaunchBoundary(cancelled);
  try {
    final helper = await launch(boundary);
    final output = helper.output;
    if (boundary.cancelledBeforeHelper && !boundary.helperAttempted) {
      return DeviceTransportResult.notSent(
          'adb', 'VSCREEN_ADB_CANCELLED_BEFORE_START', output);
    }
    if (boundary.helperAttempted &&
        helper.localExitConfirmed &&
        helper.outputComplete &&
        withdrawUncommitted()) {
      return DeviceTransportResult.notSent('adb', 'VSCREEN_ADB_NOT_COMMITTED', output);
    }
    return _unknown(output);
  } catch (error) {
    if (error.toString().contains('Busy')) {
      final output = 'ENVIRONMENT_BUSY: ${error.toString().split('Busy').last}';
      return boundary.helperAttempted
          ? _unknown(output)
          : DeviceTransportResult.notSent('adb', 'VSCREEN_ADB_ENVIRONMENT_BUSY', output);
    }
    return _unknown('ADB_ERROR: ${error.toString()}');
  }
}

DeviceTransportResult _unknown(String output) {
  // execOwned 的历史文本不能证明 commit、输出完整性或 helper/guest 退出。
  return DeviceTransportResult.unknown('adb', 'VSCREEN_ADB_START_UNCONFIRMED', output);
}

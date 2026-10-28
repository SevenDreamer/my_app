// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenActivity.{outcomeText,touchOutcomeText,message} —— 现代化重构，行为契约不变。
//! 操作结果独立于轮询状态：后台的"未开启"不能抹掉本次失败原因。
//! 「帧门拒绝会带 reason：同一个 STALE_FRAME 有四种成因，自救方式完全不同（issue #117）。」
//! 文案逐字保留（中英双份）；Flutter 侧渲染时可按 DESIGN.md 换排版但不得改自救语义。
library;

import 'support.dart';

/// 文案选择（原版 `UiText.choose`）；默认中文。
typedef UiTextChoose = String Function(String zh, String en);

String _defaultChoose(String zh, String en) => zh;

/// 启动/操作结果文案（原版 `outcomeText`）。
String outcomeText(Map<String, Object?> value, {UiTextChoose choose = _defaultChoose}) {
  if (!value.optBoolean('ok') &&
      value.optBoolean('cleanupPending') &&
      value.has('cleanupIdentityAvailable')) {
    if (!value.optBoolean('cleanupIdentityAvailable')) {
      return choose(
          '启动结果未知，完整核心出生身份未记录，不能安全核验退出或重新创建。记录仍保留；若启动回包完全丢失，需真实重启手机后再核验。',
          'The launch result is unknown and its full core birth identity was not captured. Exit cannot be safely verified and another screen cannot be created. The record is retained; if the launch reply was lost, restart the phone before checking again.');
    }
    final channel = switch (value.optString('cleanupChannel')) {
      'root' => 'Root',
      'shizuku' => 'Shizuku',
      'adb' => 'ADB',
      _ => choose('原通道', 'original channel'),
    };
    if (value.optString('cleanupProbeReason') == 'ORIGINAL_CHANNEL_UNAVAILABLE') {
      return choose('已保存完整核心身份，但原通道 ', 'The full core identity is retained, but ') +
          channel +
          choose(' 当前不可用。恢复该通道后点“关闭”核验；尚未确认退出。',
              ' is unavailable. Restore that channel and tap Close to verify exit; exit is still unconfirmed.');
    }
    if (value.optString('reason') == 'VSCREEN_JOURNAL_UNAVAILABLE') {
      return choose(
          '已核验核心退出，但清理终态尚未安全保存。记录仍保留；恢复存储后点“关闭”重新核验。',
          'Core exit was verified, but its terminal cleanup record could not be saved. The record is retained; restore storage and tap Close to verify again.');
    }
  }
  return value.optBoolean('ok')
      ? choose('操作完成', 'Done')
      : message(value.optString('error'), value.optString('reason'), choose: choose) +
          _cause(value);
}

/// 触摸结果文案（原版 `touchOutcomeText`）：STALE_FRAME 附 requested/current/observed。
String touchOutcomeText(Map<String, Object?>? value,
    {UiTextChoose choose = _defaultChoose}) {
  try {
    if (value == null) return message('INPUT_RESULT_UNKNOWN', '', choose: choose);
    final safe = Map<String, Object?>.of(value);
    if (value.optBoolean('executionUnknown')) {
      safe
        ..put('ok', false)
        ..put('error', 'INPUT_RESULT_UNKNOWN');
    }
    var text = outcomeText(safe, choose: choose);
    if (safe.optString('error') == 'STALE_FRAME') {
      text += ' · requested=${value.optLong('requestedFrameSeq', -1)}'
          ' current=${value.optLong('currentFrameSeq', -1)}'
          ' observed=${value.optLong('observedFrameSeq', -1)}';
    }
    return text;
  } catch (unavailable) {
    return message('INPUT_RESULT_UNKNOWN', '', choose: choose);
  }
}

String _cause(Map<String, Object?> value) {
  final cause = value.optString('cause').trim();
  return cause.isEmpty ? '' : ' · $cause';
}

/// 码→自救指引（原版 `message(code, reason)`）。
String message(String code, String reason, {UiTextChoose choose = _defaultChoose}) {
  if (code == 'VSCREEN_START_UNKNOWN') {
    return choose(
        '上次启动结果未知，已保留记录，暂不重复启动。若启动回包完全丢失，需真实重启手机后再创建。',
        'The previous launch result is unknown and its record is retained. If the launch reply was lost, restart the phone before creating another screen.');
  }
  if (code == 'VSCREEN_CLOSE_UNKNOWN' || code == 'VSCREEN_CLOSING') {
    return choose(
        '停止请求已发送，尚未确认核心退出。清理记录仍保留；可点“关闭”重新核验。',
        'Stop was requested, but core exit is unconfirmed. The cleanup record is retained; tap Close to check again.');
  }
  if (code == 'VSCREEN_DISCONNECTED') {
    return choose(
        '通道已断开，本轮操作许可已失效。重连原通道后点“关闭”核验退出，再创建。',
        'The channel disconnected and this run is invalid. Reconnect the original channel, then tap Close to verify exit before creating a screen.');
  }
  if (code == 'VSCREEN_JOURNAL_UNAVAILABLE' || code == 'VSCREEN_JOURNAL_INVALID') {
    return choose(
        '本机清理记录无法保存或核验，已阻止启动。请保留记录并查看自检与诊断。',
        'The local cleanup record cannot be saved or verified. Launch is blocked; retain the record and open diagnostics.');
  }
  if (code == 'VSCREEN_NOT_RUNNING') {
    return choose(
        '虚拟屏尚未开启或已关闭。先连接设备通道，再点“创建竖屏”或“创建横屏”；开启无障碍不会自动创建。',
        'The virtual screen has not started or was closed. Connect a device channel, then tap Create portrait or Create landscape. Accessibility does not create it automatically.');
  }
  if (code == 'STALE_FRAME') {
    if (reason == 'FRAME_NOT_OBSERVED') {
      return choose(
          '还没看过这一帧：先用 see 取一帧，再用它返回的 frameSeq 输入（status 的帧号不能用于输入）。',
          'This frame was never observed: call see first, then input with the frameSeq it returns (the frameSeq from status cannot be used for input).');
    }
    if (reason == 'FRAME_EXPIRED') {
      return choose(
          '画面已被新帧替换，触摸未完成。请看最新画面，也可自行打开“节点操作”选择系统提供的节点；不会自动转换或重发。',
          'A newer frame replaced the view and the touch did not complete. Observe the latest picture, or explicitly open Node actions to choose a system-provided node. No automatic switch or resend.');
    }
    if (reason == 'OBSERVATION_TIMEOUT') {
      return choose(
          '距上次看画面已超过 30 秒，请重新 see 再输入。',
          'More than 30 seconds passed since the last observed frame; call see again.');
    }
    return choose('画面已变化，请看最新画面后再操作', 'The view changed. Observe again.');
  }
  if (code == 'INPUT_RESULT_UNKNOWN' || code == 'VIRTUAL_INPUT_RESULT_UNKNOWN') {
    return choose(
        '输入结果未知：动作可能已执行，请先观察实际画面，不要直接重试。',
        'The input result is unknown: the action may have executed. Observe the actual screen before retrying.');
  }
  if (code == 'STALE_GENERATION') {
    return choose('画面已变化，请看最新画面后再操作', 'The view changed. Observe again.');
  }
  if (code == 'DEVICE_CHANNEL_UNAVAILABLE') {
    return choose('请先在设备能力授权中连接通道', 'Connect a device channel first');
  }
  if (code == 'ACCESSIBILITY_REQUIRED_FOR_UNICODE') {
    return choose('中文输入需要开启无障碍服务', 'Enable accessibility for Unicode input');
  }
  if (code == 'VSCREEN_TRUSTED_DISPLAY_DENIED') {
    return choose(
        '这台设备拒绝了受信任显示：当前通道（ADB/Shizuku）没有 ADD_TRUSTED_DISPLAY。请改用 Root 通道，或改用无障碍屏幕操作（读屏/点按/输入/截屏）。',
        'This device refused a trusted display: the current channel (ADB/Shizuku) has no ADD_TRUSTED_DISPLAY. Use the Root channel, or use accessibility screen actions (read, tap, input, screenshot).');
  }
  if (code == 'VSCREEN_DISPLAY_CREATE_FAILED') {
    return choose(
        '系统拒绝了创建虚拟屏。可先用无障碍屏幕操作；仍失败请到“设置 → 自检与诊断”导出日志。',
        'The system refused to create the virtual screen. Use accessibility screen actions for now; if it keeps failing, export a log from Settings → Self-check and diagnostics.');
  }
  if (code == 'VSCREEN_PERMISSION_DENIED') {
    return choose(
        '设备拒绝了这次虚拟屏操作（权限不足）。请改用 Root 通道，或改用无障碍屏幕操作。',
        'The device refused this virtual-screen operation (permission denied). Use the Root channel, or use accessibility screen actions.');
  }
  if (code == 'VSCREEN_DISPLAY_SERVICE_UNAVAILABLE') {
    return choose(
        '系统的显示服务中断了这次调用，请先确认虚拟屏状态再重试。',
        'The system display service interrupted this call; check the virtual screen state before retrying.');
  }
  return choose('未完成：', 'Not completed: ') + code;
}

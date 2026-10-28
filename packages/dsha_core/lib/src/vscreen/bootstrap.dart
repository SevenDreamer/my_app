// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenBootstrap —— 现代化重构，行为契约不变。
//! 有界启动握手：允许 ROM 的普通输出，但只信任精确的受管标记。
//! 错误契约（逐字）：`CORE_BOOTSTRAP_LIMIT`/`CORE_BOOTSTRAP_INVALID`。
library;

import 'dart:io';

import 'failures.dart';
import 'vscreen_handshake.dart';

final RegExp _errorPattern =
    RegExp(r'^DSHA_VSCREEN_ERROR=([A-Za-z0-9_]{1,160})\r?$', multiLine: true);

/// 启动握手解析（原版 `VirtualScreenBootstrap`）。
class VscreenBootstrap {
  final List<int> _line = <int>[];
  int _bytes = 0;
  String _token = '';
  VscreenHandshake? _handshake;

  VscreenHandshake? handshake() => _handshake;

  String token() => _token;

  void accept(int value) {
    if (++_bytes > 65536) throw FileSystemException('CORE_BOOTSTRAP_LIMIT');
    if (value == 0x0a /* '\n' */) {
      final text = String.fromCharCodes(_line).replaceAll('\r', '');
      _line.clear();
      final match = _errorPattern.firstMatch(text);
      final failure = match == null ? '' : match.group(1)!;
      if (failure.isNotEmpty) throw FileSystemException(failure);
      const prefix = 'DSHA_VSCREEN_BOOTSTRAP ';
      if (text.startsWith(prefix)) {
        final secret = text.substring(prefix.length);
        try {
          _handshake = VscreenHandshake.parse(secret);
          _token = _handshake!.token;
        } on Exception {
          throw FileSystemException('CORE_BOOTSTRAP_INVALID');
        }
      }
    } else {
      if (_line.length >= 4096) throw FileSystemException('CORE_BOOTSTRAP_LIMIT');
      _line.add(value);
    }
  }

  /// 从输出提取失败码（原版 `error`）。
  static String error(String? output) {
    if (output == null) return '';
    final match = _errorPattern.firstMatch(output);
    return match != null ? match.group(1)! : startFailureCode(output);
  }

  /// 只返回固定诊断码；绝不把启动输出或凭据抄进日志。
  static String startFailureCode(String? output) {
    if (output == null) return '';
    for (final stage in const ['START', 'COMMIT']) {
      for (final reason in const [
        'AUTH_REJECTED',
        'TICKET_REJECTED',
        'PATH_UNVERIFIED',
        'CHANNEL_UNAVAILABLE',
        'PLAN_REJECTED',
        'CREDENTIAL_UNAVAILABLE',
        'HTTP_ERROR',
        'TIMEOUT',
        'CONNECT_FAILED',
        'INVALID_RESPONSE',
        'FAILED',
      ]) {
        final code = 'ADB_${stage}_BRIDGE_$reason';
        if (output.contains(code)) return code;
      }
    }
    if (output.contains('ENVIRONMENT_BUSY')) return 'ADB_ENVIRONMENT_BUSY';
    if (output.contains('Native virtual-screen launch ticket missing')) {
      return 'ADB_TICKET_MISSING';
    }
    if (output.contains('Invalid native virtual-screen ticket')) return 'ADB_TICKET_INVALID';
    if (output.contains('[POLICY_BLOCKED]')) return 'ADB_POLICY_BLOCKED';
    if (output.contains('ADB_PROCESS_EXIT_UNCONFIRMED')) return 'ADB_PROCESS_EXIT_UNCONFIRMED';
    if (output.contains('EXECUTION_UNKNOWN')) return 'ADB_EXECUTION_UNKNOWN';
    if (output.contains('CONNECT_FAIL:')) return 'ADB_CONNECT_FAILED';
    if (output.contains('NO_KEY:')) return 'ADB_PAIRING_KEY_MISSING';
    if (output.contains('DEPS_MISSING:')) return 'ADB_DEPENDENCIES_MISSING';
    if (output.contains('INVALID_ARGUMENT:')) return 'ADB_INVALID_ARGUMENT';
    if (output.contains('ADB_CANCELLED:')) return 'ADB_CANCELLED';
    if (output.contains('ADB_ERROR:')) return 'ADB_PROCESS_FAILED';
    return '';
  }

  /// 只记录既定机器码，绝不记录任意异常/桥消息。
  static String diagnosticCode(String? code) {
    if (code == null) return 'VSCREEN_FAILURE_UNCLASSIFIED';
    if (RegExp(
            r'^VSCREEN_CORE_[A-Z_]{1,32}_SDK[0-9]{1,3}_(?:PERMISSION_DENIED|DISPLAY_SERVICE_UNAVAILABLE|NATIVE_API_UNAVAILABLE|INVALID_DISPLAY_REQUEST|DISPLAY_STATE|DISPLAY_IO|OPERATION_FAILED|DISPLAY_CREATE_FAILED)$')
        .hasMatch(code)) {
      return code;
    }
    if (code.startsWith('VSCREEN_ADB_')) {
      final suffix = code.substring('VSCREEN_'.length);
      if (suffix == startFailureCode(suffix)) return code;
    }
    for (final known in const [
      'VSCREEN_NOT_RUNNING',
      'VSCREEN_START_IN_PROGRESS',
      'VSCREEN_REVOKED',
      'VSCREEN_START_CANCELLED',
      'VSCREEN_START_RESULT_UNKNOWN',
      'VSCREEN_START_UNKNOWN',
      'VSCREEN_DISCONNECTED',
      'VSCREEN_CLOSE_UNKNOWN',
      'VSCREEN_JOURNAL_UNAVAILABLE',
      'VSCREEN_JOURNAL_INVALID',
      'VSCREEN_TRANSPORT_UNAVAILABLE',
      'DEVICE_CHANNEL_UNAVAILABLE',
      'SCREEN_TARGET_CHANGED',
      'VSCREEN_UNSUPPORTED_LOW',
      'VSCREEN_API_30_REQUIRED',
      'VSCREEN_APPLICATION_SCOPE_UNAVAILABLE',
      'INVALID_ORIENTATION',
      'STALE_GENERATION',
      'STALE_FRAME',
      'INPUT_RESULT_UNKNOWN',
      'INPUT_REJECTED',
      'VSCREEN_INPUT_UNAVAILABLE',
      'VSCREEN_PERMISSION_DENIED',
      'VSCREEN_TRUSTED_DISPLAY_DENIED',
      'VSCREEN_DISPLAY_SERVICE_UNAVAILABLE',
      'VSCREEN_DISPLAY_CREATE_FAILED',
      'VSCREEN_INVALID_DISPLAY_REQUEST',
      'VSCREEN_DISPLAY_STATE',
      'VSCREEN_DISPLAY_IO',
      'VSCREEN_OPERATION_FAILED',
      'VSCREEN_NATIVE_API_UNAVAILABLE',
      'INVALID_PACKAGE',
      'INVALID_TEXT',
      'ACCESSIBILITY_REQUIRED_FOR_UNICODE',
      'INVALID_NODE_ACTION',
      'INVALID_EDITOR_ARGUMENTS',
      'VSCREEN_RESPONSE_LIMIT',
      'INVALID_EDITOR_OPERATION',
    ]) {
      if (known == code) return code;
    }
    return 'VSCREEN_FAILURE_UNCLASSIFIED';
  }

  static String failureCode(String stage, int sdk, Object? failure) {
    final propagated = error('DSHA_VSCREEN_ERROR=${_messageOf(failure)}');
    if (propagated.isNotEmpty && propagated.startsWith('CORE_')) return propagated;
    final type = VscreenFailures.code(failure).substring('VSCREEN_'.length);
    final safeStage = RegExp(r'^[A-Z_]{1,32}$').hasMatch(stage) ? stage : 'START';
    return 'CORE_${safeStage}_SDK${sdk < 0 ? 0 : sdk}_$type';
  }

  static String? _messageOf(Object? failure) {
    if (failure == null) return null;
    final dynamic e = failure;
    try {
      final message = e.message;
      return message is String ? message : message?.toString();
    } on Exception {
      return null;
    }
  }
}

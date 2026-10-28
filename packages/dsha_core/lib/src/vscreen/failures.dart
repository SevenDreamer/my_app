// 版权来源：DSHA（MIT）com.deepseekharness.app.util.VirtualScreenFailures —— 现代化重构，行为契约不变。
//! 虚拟屏 core 的稳定错误码与根因摘要。
//! 对外错误码只表达「发生了什么、下一步做什么」，绝不把异常类名当语义；
//! 但根因摘要必须一起给出——只留类名等于把唯一能定位的信息扔掉。
library;

import 'dart:io';

import '../install/sensitive_data.dart' show redact;

/// 稳定码 + 根因摘要（原版 `VirtualScreenFailures`）。
abstract final class VscreenFailures {
  static const String permissionDenied = 'VSCREEN_PERMISSION_DENIED';
  static const String displayServiceUnavailable = 'VSCREEN_DISPLAY_SERVICE_UNAVAILABLE';
  static const String nativeApiUnavailable = 'VSCREEN_NATIVE_API_UNAVAILABLE';
  static const String invalidRequest = 'VSCREEN_INVALID_DISPLAY_REQUEST';
  static const String displayState = 'VSCREEN_DISPLAY_STATE';
  static const String displayIo = 'VSCREEN_DISPLAY_IO';
  static const String operationFailed = 'VSCREEN_OPERATION_FAILED';
  static const String trustedDisplayDenied = 'VSCREEN_TRUSTED_DISPLAY_DENIED';
  static const String displayCreateFailed = 'VSCREEN_DISPLAY_CREATE_FAILED';

  /// 根因摘要上限：够放下一个方法签名，又不至于把响应与日志刷爆。
  static const int maxCause = 200;

  static String startFailure(Object? error) {
    for (final current in _chain(error)) {
      final text = _messageOf(current);
      if (text != null && RegExp(r'^VSCREEN_[A-Z0-9_]{1,64}$').hasMatch(text)) {
        return text;
      }
    }
    return code(error);
  }

  /// 稳定码：**先认最深层根因**——真正可操作的失败被包装在
  /// `IllegalStateException`/`InvocationTargetException` 里面，只看最外层会误报。
  /// 根因认不出来时，再沿链取第一个能识别的类别。
  static String code(Object? error) {
    final chain = _semanticChain(error);
    if (chain.isEmpty) return operationFailed;
    final root = _classify(chain.last);
    if (root != null) return root;
    for (final current in chain) {
      final classified = _classify(current);
      if (classified != null) return classified;
    }
    return operationFailed;
  }

  /// 根因摘要：最深层原因的类名 + message，折叠空白、过脱敏、截断到 [maxCause]。
  static String cause(Object? error) {
    final chain = _semanticChain(error);
    if (chain.isEmpty) return '';
    final root = chain.last;
    final message = _messageOf(root);
    var text = (message == null || message.trim().isEmpty)
        ? root.runtimeType.toString()
        : '${root.runtimeType}: $message';
    text = redact(text).replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > maxCause ? '${text.substring(0, maxCause)}…' : text;
  }

  /// 单个异常的类别；认不出来返回 null，由调用方决定回退顺序。
  ///
  /// 反射/远端两类按类名判定（与原版同位）；参数/状态/IO 按 Dart 类型判定。
  static String? _classify(Object error) {
    final name = error.runtimeType.toString();
    if (name == 'NoSuchMethodException' ||
        name == 'NoSuchFieldException' ||
        name == 'ClassNotFoundException' ||
        name == 'LinkageError') {
      return nativeApiUnavailable;
    }
    if (name == 'SecurityException') return permissionDenied;
    if (name == 'RemoteException' || name == 'DeadObjectException') {
      return displayServiceUnavailable;
    }
    if (error is ArgumentError) return invalidRequest;
    if (error is StateError) return displayState;
    if (error is IOException) {
      return _messageOf(error) == 'DISPLAY_CREATE_FAILED' ? displayCreateFailed : displayIo;
    }
    return null;
  }

  /// 有界、去环的异常链（16 上限；自指 cause 不得转死）。
  static List<Object> _chain(Object? error) {
    final chain = <Object>[];
    final seen = <Object>{};
    Object? current = error;
    while (current != null && chain.length < 16 && seen.add(current)) {
      chain.add(current);
      current = _causeOf(current);
    }
    return chain;
  }

  /// Parcel 附加的远端栈只是诊断附件，不是覆盖外层 Security/参数异常的根因。
  static List<Object> _semanticChain(Object? error) {
    final chain = _chain(error);
    while (chain.length > 1) {
      final last = chain.last;
      final message = _messageOf(last);
      if (last.runtimeType.toString() != 'RemoteException' ||
          message == null ||
          !message.startsWith('Remote stack trace:')) {
        break;
      }
      chain.removeLast();
    }
    return chain;
  }

  static String? _messageOf(Object error) {
    final dynamic e = error;
    try {
      final message = e.message;
      return message is String ? message : message?.toString();
    } on Exception {
      return null;
    }
  }

  /// 异常因链缝：实现了 `Caused` 的异常可携带原因（原版 `Throwable.getCause()`）。
  static Object? _causeOf(Object error) {
    if (error is Caused) return error.cause;
    return null;
  }
}

/// 异常因链缝（原版 `Throwable.getCause()` 语义）。
abstract interface class Caused {
  Object? get cause;
}

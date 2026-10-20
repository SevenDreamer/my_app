//! AppError：带错误码的统一错误对象（人话 + 原文 + 建议）
import 'dart:async';
import 'dart:io';

import 'error_codes.dart';

class AppError {
  const AppError({
    required this.code,
    required this.message,
    this.detail,
    this.hint,
    this.context,
  });

  /// 错误码（见 error_codes.dart）
  final String code;

  /// 人话描述（一句话说清发生了什么）
  final String message;

  /// 技术原文（完整异常串，供复制排查）
  final String? detail;

  /// 处理建议
  final String? hint;

  /// 出错场景（如"授权"、"扫码下载"）
  final String? context;

  /// 复制带走的完整文本（码+场景+人话+原文）
  String get fullText {
    final b = StringBuffer('[$code ${ErrorCodes.categoryOf(code)}]');
    if (context != null) b.write(' $context');
    b.write('\n$message');
    if (hint != null) b.write('\n建议：$hint');
    if (detail != null) b.write('\n\n$detail');
    return b.toString();
  }

  /// 从任意异常映射为带码错误（识别常见异常类型自动归码）
  static AppError from(
    Object e, {
    String code = ErrorCodes.unknown,
    String? message,
    String? hint,
    String? context,
  }) {
    var resolved = code;
    var resolvedHint = hint;

    final text = e.toString();
    // 连接中断/复位类（package:http 的 ClientException 或字符串特征）
    if (text.contains('connection abort') ||
        text.contains('Connection reset') ||
        text.contains('Software caused connection') ||
        text.contains('Connection closed')) {
      resolved = ErrorCodes.netTimeout;
      resolvedHint ??= '网络连接中断：多为网络抖动/切换或省电策略掐断，'
          '重试一次通常即可；持续出现请切换网络（Wi-Fi ↔ 流量）。';
    } else if (e is SocketException) {
      // DNS 解析失败（Failed host lookup）/ 连接失败
      if (text.contains('Failed host lookup') ||
          text.contains('No address associated')) {
        resolved = ErrorCodes.netDns;
        resolvedHint ??= '手机无法解析域名（DNS）：检查当前网络，或切换 Wi-Fi/流量重试；'
            'github.com 在部分网络下需要代理。';
      } else {
        resolved = ErrorCodes.netTimeout;
        resolvedHint ??= '网络连接失败：检查网络连通性后重试。';
      }
    } else if (e is TimeoutException) {
      resolved = ErrorCodes.netTimeout;
      resolvedHint ??= '请求超时：网络较慢或服务器无响应，稍后重试。';
    } else if (e is HttpException) {
      resolved = ErrorCodes.netOther;
    }

    return AppError(
      code: resolved,
      message: message ?? _defaultMessage(resolved),
      detail: e.toString(),
      hint: resolvedHint,
      context: context,
    );
  }

  static String _defaultMessage(String code) {
    switch (code) {
      case ErrorCodes.netDns:
        return '域名解析失败（无法连接服务器）';
      case ErrorCodes.netTimeout:
        return '网络请求失败或超时';
      case ErrorCodes.netUnavailable:
        return '当前网络不可用';
      case ErrorCodes.authNone:
        return '尚未授权 GitHub';
      case ErrorCodes.authExpired:
        return '授权已过期';
      case ErrorCodes.updateNoApk:
        return '最新版本还没有 Android 安装包';
      default:
        return '发生未知错误';
    }
  }
}

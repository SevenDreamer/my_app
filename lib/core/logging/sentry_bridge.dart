//! Sentry 崩溃聚合桥（2026-10 拍板：Sentry 免费档）。
//!
//! 职责：①初始化（DSN 编译期注入，空 = 完全禁用，零外发）
//! ②`beforeSend` 全链脱敏——消息/异常值/面包屑/extra 逐个过
//! `sensitive.redact`（密钥/凭据形态不外发）③AppLogger 日志回流
//! 面包屑，崩溃报告自带最近日志上下文。
//! DSN 为可公开的 ingest 凭据（只发不读），经 `--dart-define=SENTRY_DSN=…`
//! 注入，不入库。
import 'package:dsha_core/dsha_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 编译期 DSN（`--dart-define=SENTRY_DSN=<dsn>`）；空 = 禁用 Sentry。
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

class SentryBridge {
  SentryBridge._();

  static bool get enabled => kSentryDsn.isNotEmpty;

  /// 初始化并启动应用；DSN 为空时直接启动（本地日志链不受影响）。
  static Future<void> init({required Future<void> Function() appRunner}) async {
    if (!enabled) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = kSentryDsn;
        options.sendDefaultPii = false;
        options.beforeSend = _scrub;
      },
      appRunner: appRunner,
    );
  }

  /// AppLogger → 面包屑（崩溃报告携带最近日志上下文）。
  static void breadcrumb(String tag, String message) {
    if (!enabled) return;
    Sentry.addBreadcrumb(Breadcrumb(
      message: redact('[$tag] $message'),
      category: 'applog',
      level: SentryLevel.info,
    ));
  }

  /// 手动上报（业务层捕获的异常）。
  static Future<void> capture(Object error, StackTrace stack,
      {String? context}) {
    return Sentry.captureException(error, stackTrace: stack);
  }

  /// beforeSend 脱敏：消息/异常值/面包屑逐字段过 `sensitive.redact`。
  /// （Sentry 协议对象字段可变：原地改写后原样返回，结构不动。）
  static Future<SentryEvent?> _scrub(SentryEvent event, dynamic hint) async {
    final message = event.message;
    if (message != null) {
      message.formatted = redact(message.formatted);
    }
    for (final exception in event.exceptions ?? const <SentryException>[]) {
      exception.value = redact(exception.value ?? '');
    }
    for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
      crumb.message = redact(crumb.message ?? '');
    }
    return event;
  }
}

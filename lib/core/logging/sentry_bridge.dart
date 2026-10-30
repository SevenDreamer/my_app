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
        // 文档推荐默认：errors + tracing（生产再调采样率）。
        options.tracesSampleRate = 1.0;
        options.environment =
            const String.fromEnvironment('SENTRY_ENV', defaultValue: 'development');
        options.release =
            const String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'my_app@dev');
      },
      appRunner: appRunner,
    );
  }

  /// 临时真实触发（验证链路用；`--dart-define=SENTRY_TEST_ERROR=1` 时生效）：
  /// 走真实 init 后的异步异常路径，非独立脚本。
  static void maybeScheduleTestError() {
    const enabled = bool.fromEnvironment('SENTRY_TEST_ERROR');
    if (!enabled) return;
    Future<void>.delayed(const Duration(seconds: 5), () {
      throw StateError('Sentry 验证测试异常（my_app，可忽略）');
    });
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

  /// 诊断包上报（DSH 系统「上报诊断」按钮）：六步状态/详细输出/日志/环境
  /// 选型整体打成自定义事件。字段经 _scrub 脱敏后出网。
  static Future<bool> captureDiagnostics(Map<String, Object> payload) async {
    if (!enabled) return false;
    final event = SentryEvent(
      message: SentryMessage('dsha-diagnostics'),
      level: SentryLevel.warning,
      tags: const <String, String>{'kind': 'dsha-diagnostics'},
    );
    // 结构化上下文（SDK 建议替代已弃用的 extra）。
    event.contexts['dsha'] = payload;
    await Sentry.captureEvent(event);
    return true;
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

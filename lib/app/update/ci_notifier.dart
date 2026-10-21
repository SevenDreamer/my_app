//! 手机端 GitHub 流水线通知（拉模式）
//!
//! 拉模式的理由：私仓无自建服务器收不了 webhook——app 前台定期查
//! GitHub Actions runs API（复用 Device Flow 授权 token），有新结果就弹
//! 系统通知栏（成功✅/失败❌）。已通知的 run id 落盘去重，不重复弹。
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'github_auth_service.dart';

class CiNotifier {
  CiNotifier._();
  static final CiNotifier instance = CiNotifier._();

  static const _storage = FlutterSecureStorage();
  static const _kEnabled = 'ci_notify_enabled';
  static const _kNotifiedRun = 'ci_notified_run_id';
  static const _channel = AndroidNotificationDetails(
    'ci_channel',
    '流水线通知',
    channelDescription: 'GitHub Actions 构建结果通知',
    importance: Importance.high,
    priority: Priority.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _inited = false;

  /// 初始化（main 调用）：开通知权限 + 按开关启动轮询
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (await enabled) {
      // ignore: unawaited_futures
      startPolling();
    }
  }

  /// 开关（默认开）
  Future<bool> get enabled async =>
      (await _storage.read(key: _kEnabled)) != '0';

  Future<void> setEnabled(bool value) async {
    await _storage.write(key: _kEnabled, value: value ? '1' : '0');
    if (value) {
      await startPolling();
    } else {
      stopPolling();
    }
  }

  /// 启动前台轮询（每 5 分钟查一次最新 run）
  Future<void> startPolling(
      {Duration interval = const Duration(minutes: 5)}) async {
    stopPolling();
    // 申请 Android 13+ 通知权限（首次弹系统授权框）
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // ignore: unawaited_futures
    android?.requestNotificationsPermission();
    await checkOnce();
    _timer = Timer.periodic(interval, (_) => checkOnce());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// 查一次最新流水线 run；有新结果弹通知（去重）
  Future<void> checkOnce() async {
    try {
      final token = await GithubAuthService().validToken();
      if (token == null) return; // 未授权——静默跳过（不打扰）
      final resp = await http.get(
        Uri.parse(
            'https://api.github.com/repos/SevenDreamer/my_app/actions/runs?per_page=5'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (resp.statusCode != 200) return;
      final runs =
          (jsonDecode(utf8.decode(resp.bodyBytes))['workflow_runs'] as List?) ??
              const [];
      if (runs.isEmpty) return;
      // 找最新的「开发版发布」run（其他流水线不打扰）
      Map<String, dynamic>? latest;
      for (final r in runs) {
        if ((r['name'] as String? ?? '').contains('开发版')) {
          latest = Map<String, dynamic>.from(r as Map);
          break;
        }
      }
      if (latest == null) return;

      final runId = '${latest['id']}';
      final lastNotified = await _storage.read(key: _kNotifiedRun);
      if (runId == lastNotified) return; // 已通知过

      // 只在 run 结束（有结论）时通知
      final conclusion = latest['conclusion'] as String?;
      if (conclusion == null || conclusion.isEmpty) return;

      final ok = conclusion == 'success';
      final title = ok ? '✅ 流水线构建成功' : '❌ 流水线构建失败';
      final version = latest['display_title'] as String? ?? '';
      final body = ok
          ? '$version 已发布，可在更新检查下载'
          : '$version 构建失败（$conclusion），点开 GitHub 查看日志';

      await _plugin.show(
        id: 20261021,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _channel),
      );
      await _storage.write(key: _kNotifiedRun, value: runId);
    } catch (_) {
      // 网络抖动等静默吞掉——通知是增值功能，不能影响 app
    }
  }
}

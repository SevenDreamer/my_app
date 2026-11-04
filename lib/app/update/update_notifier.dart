//! 更新/热更/自测的系统通知（flutter_local_notifications）
//!
//! 三类通知共用「更新提醒」渠道，点击行为统一为「拉起 App」：
//! ① 发现新版本——进 App 走既有更新流程（启动门自动下载安装）；
//! ② 热更就绪——进 App 后启动门自动下载 patch 并重启生效；
//! ③ 更新完成待自测——进 App 直接弹自动测试（payload 'selftest'）。
//! 点击动作经 payload 分发；冷启动点通知进入的场景走
//! [getNotificationAppLaunchDetails] 补取（initialize 时一次性消费）。
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'update_service.dart';

class UpdateNotifier {
  UpdateNotifier._();

  static const _channelId = 'my_app/update';
  static const _channelName = '更新提醒';
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// payload：点击「更新完成待自测」通知进入 App 直接弹自动测试
  static const payloadSelfTest = 'selftest';

  static String? _pendingAction;
  static bool _initialized = false;

  /// 初始化（幂等）：渠道 + 点击回调 + 冷启动动作补取 +（Android 13+）通知权限
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    const settings = InitializationSettings(
      // 复用现有启动图标，零新增资产（PITFALLS #27：资产变更拦住 patch）
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onTap,
    );
    // 冷启动（进程被通知拉起）的点击动作在 launch details 里，补取一次
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _pendingAction = launch!.notificationResponse?.payload;
      }
    } catch (_) {}
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// 消费点击动作（'selftest' / null）；一次即清
  static String? consumeLaunchAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  static void _onTap(NotificationResponse response) {
    _pendingAction = response.payload;
  }

  /// ① 发现新版本（去重由调用方负责，见后台巡检）
  static Future<void> newVersion(UpdateInfo info) => _show(
        id: 1001,
        title: '发现新版本 v${info.version}',
        body: info.notes.isEmpty ? '点击查看并更新' : info.notes,
      );

  /// ② 热更新就绪（点击进 App，启动门自动应用）
  static Future<void> newPatch(PatchInfo patch) => _show(
        id: 1002,
        title: '热更新 Patch ${patch.number} 已就绪',
        body: patch.notes.isEmpty ? '点击进入应用后自动生效' : patch.notes,
      );

  /// ③ 更新完成待自测（点击直接弹自动测试）
  static Future<void> selfTestReady(String version) => _show(
        id: 1003,
        title: 'v$version 更新完成',
        body: '点击开始自动测试',
        payload: payloadSelfTest,
      );

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '新版本与热更新提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}

//! 后台更新巡检（WorkManager 周期任务）
//!
//! 「应用放在后台也要收到更新通知」：Android 用 WorkManager 周期任务
//! 按周期醒来检查——app 被杀也能跑（WorkManager 自管调度），发现
//! 新版本/热更 patch 就发系统通知（同版本/同 patch 只通知一次）。
//! 其他平台不注册（维持既有「启动门检查」路径）；巡检任何异常静默
//! 落盘，绝不打扰、绝不重试风暴（返回 true 免 WorkManager 重试）。
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_log.dart';
import 'update_notifier.dart';
import 'update_service.dart';

const _kTaskName = 'my_app/update_check';
const _kNotifiedVersionKey = 'bg_notified_version';
const _kNotifiedPatchKey = 'bg_notified_patch';

/// WorkManager 后台入口（独立 isolate，必须顶层 + vm:entry-point）
@pragma('vm:entry-point')
void updateCheckDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await UpdateNotifier.init();
      await _checkVersion();
      await _checkPatch();
    } catch (e) {
      await ErrorLog.record(AppError.from(e, context: '后台更新巡检'));
    }
    // 巡检失败不重试（下次周期自然再来），避免网络故障期的重试风暴
    return true;
  });
}

/// 大版本：复用 UpdateService.check()（semver 对比 + 忽略本版过滤）
Future<void> _checkVersion() async {
  final info = await UpdateService().check();
  if (info == null) return;
  const storage = FlutterSecureStorage();
  if (await storage.read(key: _kNotifiedVersionKey) == info.version) return;
  await storage.write(key: _kNotifiedVersionKey, value: info.version);
  await UpdateNotifier.newVersion(info);
}

/// 热更：manifest `patch` 节领先「当前已生效 patch」才通知。
/// patch 只对目标 release（version+build 全号）有意义——不同号设备不通知。
Future<void> _checkPatch() async {
  final updater = ShorebirdUpdater();
  if (!updater.isAvailable) return;
  final patch = (await UpdateService().latest())?.patch;
  if (patch == null) return;
  final info = await PackageInfo.fromPlatform();
  final current = '${info.version}+${info.buildNumber}';
  if (patch.release != current) return;
  final applied = (await updater.readCurrentPatch())?.number ?? 0;
  if (patch.number <= applied) return;
  const storage = FlutterSecureStorage();
  final key = patch.number.toString();
  if (await storage.read(key: _kNotifiedPatchKey) == key) return;
  await storage.write(key: _kNotifiedPatchKey, value: key);
  await UpdateNotifier.newPatch(patch);
}

class BackgroundUpdateCheck {
  BackgroundUpdateCheck._();

  /// 注册周期巡检（幂等；ExistingWorkPolicy.keep 不重复排任务）。
  /// 仅 Android：WorkManager 是 Android 后台机制，其他平台走启动门。
  static Future<void> register() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await Workmanager().initialize(updateCheckDispatcher);
    await Workmanager().registerPeriodicTask(
      _kTaskName,
      _kTaskName,
      frequency: const Duration(hours: 2),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

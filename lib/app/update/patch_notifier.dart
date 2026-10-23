//! 热更新提示器（Shorebird）——静默下载、重启生效时提示
//!
//! Shorebird auto_update 在启动时静默下载 patch、下次启动生效——用户感受不到。
//! 本组件对比「当前 patch 号」与上次提示记录，变了就提示「已应用热更新 Patch N」，
//! 让热更可见（不打扰——AppToast 顶部滑出自动消失）。
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../design/widgets/app_toast.dart';

class PatchNotifier {
  PatchNotifier._();

  static const _kKey = 'patch_notified_number';

  /// 启动时调用：当前 patch 与上次提示记录不同 → 提示「已应用热更新」
  static Future<void> checkOnLaunch(BuildContext context) async {
    try {
      final updater = ShorebirdUpdater();
      if (!updater.isAvailable) return;
      final current = await updater.readCurrentPatch();
      final number = current?.number ?? 0;
      const storage = FlutterSecureStorage();
      final last = await storage.read(key: _kKey);
      if (last != number.toString()) {
        await storage.write(key: _kKey, value: number.toString());
        if (last != null && number > 0 && context.mounted) {
          AppToast.show(context, '已应用热更新 Patch $number');
        }
      }
    } catch (_) {
      // 热更状态读取失败不影响启动
    }
  }
}

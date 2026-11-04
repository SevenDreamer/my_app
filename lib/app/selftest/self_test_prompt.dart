//! 自动测试入口：更新后首启提示 + 通知点击路由
//!
//! 满足其一即弹自动测试对话框：
//! ① 更新后首启——「上次运行版本」≠ 当前 version+build（首装不算：无记录
//!    只登记不弹）；弹过即登记，同版本不重复打扰。
//! ② 通知点击——「更新完成待自测」通知的 payload（含冷启动点入）。
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'self_test_dialog.dart';
import '../update/update_notifier.dart';

const _kLastRunVersionKey = 'selftest_last_run_version';

/// 包裹放行后的主界面：时机到了就弹自动测试（不拦截、不延迟进主页）
class SelfTestPrompt extends StatefulWidget {
  const SelfTestPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<SelfTestPrompt> createState() => _SelfTestPromptState();
}

class _SelfTestPromptState extends State<SelfTestPrompt> {
  @override
  void initState() {
    super.initState();
    _maybePrompt();
  }

  Future<void> _maybePrompt() async {
    final action = UpdateNotifier.consumeLaunchAction();
    final versionChanged = await _markVersion();
    if (action != UpdateNotifier.payloadSelfTest && !versionChanged) return;
    if (!mounted) return;
    await showSelfTestDialog(context);
  }

  /// 登记本次运行版本；返回「是否是更新后首启」（有旧记录且不同才算）
  Future<bool> _markVersion() async {
    final info = await PackageInfo.fromPlatform();
    final current = '${info.version}+${info.buildNumber}';
    const storage = FlutterSecureStorage();
    final last = await storage.read(key: _kLastRunVersionKey);
    await storage.write(key: _kLastRunVersionKey, value: current);
    return last != null && last != current;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

//! "我"页面：个人信息与设置（占位阶段）
//!
//! 设置/关于/更新入口；后续接账号、偏好设置、设备管理等。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../design/widgets/app_toast.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design/tokens.dart';
import '../design/widgets/app_header.dart';
import '../design/widgets/app_scaffold.dart';
import '../design/widgets/app_setting_row.dart';
import 'about_page.dart';
import 'error_log_page.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'update/download_qr.dart';
import 'update/update_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _patchInfo = '检测中…';

  @override
  void initState() {
    super.initState();
    // ignore: unawaited_futures
    _refreshPatchInfo();
  }

  /// 更新中心：热更（Shorebird patch）+ 大版本（R2 manifest）两层检查
  Future<void> _checkUpdates() async {
    final sb = StringBuffer();
    try {
      final updater = ShorebirdUpdater();
      final current = await updater.readCurrentPatch();
      final next = await updater.readNextPatch();
      sb.writeln('热更：Patch ${current?.number ?? 0}（当前生效）');
      sb.writeln(
          next != null ? '热更新已下载，重启应用后生效（Patch ${next.number}）' : '热更：无待生效补丁');
    } catch (e) {
      sb.writeln('热更：$e');
    }
    final info = await UpdateService().check();
    sb.writeln(info != null ? '大版本：${info.version} 可更新' : '大版本：已是最新');
    if (!mounted) return;
    await showShadDialog(
      context: context,
      builder: (ctx) => ShadDialog(
        title: const Text('检查更新'),
        description: Text(sb.toString()),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 热更状态（当前 Patch 号 + 是否有已下载待重启的更新）
  Future<void> _refreshPatchInfo() async {
    try {
      final updater = ShorebirdUpdater();
      final current = await updater.readCurrentPatch();
      final next = await updater.readNextPatch();
      final text = 'Patch ${current?.number ?? '基线（无补丁）'}'
          '${next != null ? ' · Patch ${next.number} 已下载，重启生效' : ''}';
      if (mounted) setState(() => _patchInfo = text);
    } catch (e) {
      if (mounted) setState(() => _patchInfo = '非热更包/检测失败：$e');
    }
  }

  /// 占位动作：敬请期待
  void _comingSoon() {
    AppToast.show(context, '敬请期待');
  }

  /// 扫码下载是桌面端入口（手机自己不需要下载自己）
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '我'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 设置与关于
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingRow(
                  icon: LucideIcons.settings,
                  title: '设置',
                  onTap: _comingSoon,
                ),
                AppSettingRow(
                  icon: LucideIcons.bug,
                  title: '错误日志',
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => const ErrorLogPage(),
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  ),
                ),
                if (_isDesktop)
                  AppSettingRow(
                    icon: LucideIcons.qrCode,
                    title: '手机下载',
                    onTap: () => showDownloadQrDialog(context),
                  ),
                AppSettingRow(
                  icon: LucideIcons.refreshCw,
                  title: '检查更新',
                  trailing: ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: _checkUpdates,
                    child: const Text('检查'),
                  ),
                ),
                AppSettingRow(
                  // wrench：patch=补丁语义；且必须用 release 已有的字形——
                  // 图标字体按字形裁剪，新字形会变资产差异拦住 patch（PITFALLS）
                  icon: LucideIcons.zap,
                  title: '热更状态',
                  detail: _patchInfo,
                  onTap: _refreshPatchInfo,
                ),
                AppSettingRow(
                  icon: LucideIcons.info,
                  title: '关于',
                  showDivider: false,
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => const AboutPage(),
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

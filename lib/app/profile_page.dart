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
import 'selftest/self_test_dialog.dart';

import 'update/download_qr.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
                // 自动测试手动入口（图标复用已有字形——PITFALLS #27 护 patch）
                AppSettingRow(
                  icon: LucideIcons.check,
                  title: '自动测试',
                  onTap: () => showSelfTestDialog(context),
                ),
                if (_isDesktop)
                  AppSettingRow(
                    icon: LucideIcons.qrCode,
                    title: '手机下载',
                    onTap: () => showDownloadQrDialog(context),
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

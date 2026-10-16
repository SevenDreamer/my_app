//! "我"页面：个人信息与设置（占位阶段）
//!
//! 目前只放身份区与设置/关于入口，后续接账号、偏好设置、设备管理等。
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design/tokens.dart';
import '../design/widgets/app_app_bar.dart';
import '../design/widgets/app_list_tile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 版本信息从 pubspec.yaml 读取
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  /// 占位动作：敬请期待
  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('敬请期待')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const AppAppBar(title: '我'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 身份区
          ShadCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'my_app',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('个人工具箱', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 设置与关于
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListTile(
                  icon: LucideIcons.settings,
                  title: '设置',
                  showDivider: true,
                  onTap: _comingSoon,
                ),
                AppListTile(
                  icon: LucideIcons.info,
                  title: '关于',
                  subtitle: '个人工具箱 · 遵循 DESIGN.md 视觉规范',
                  trailing: FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? 'v${snapshot.data!.version}'
                          : '…',
                      style: textTheme.labelSmall,
                    ),
                  ),
                  showDivider: false,
                  onTap: _comingSoon,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//! "我"页面：个人信息与设置（占位阶段）
//!
//! 目前只放身份区与设置/关于入口，后续接账号、偏好设置、设备管理等。
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design/tokens.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('我')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 身份区
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'my_app',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '个人工具箱',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.secondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 设置与关于
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _comingSoon,
                ),
                const Divider(height: 1, indent: AppSpacing.lg),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  subtitle: FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? '版本 ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                          : '版本信息加载中…',
                    ),
                  ),
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

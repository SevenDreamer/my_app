//! 主界面：功能列表主页
//!
//! 功能清单来自注册表（feature_registry.dart），
//! 按当前平台能力过滤展示：不支持的隐藏，受限的标注说明。
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../design/tokens.dart';
import '../feature_registry.dart';

/// 主界面：功能列表。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 版本信息从 pubspec.yaml 读取（version: 1.0.0+1），后续升级逻辑也基于它
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    // 当前平台不支持的功能不展示；受限功能在副标题标注
    final features = kFeatures
        .where((f) => f.support != PlatformSupport.none)
        .toList(growable: false);
    final mutedStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppColors.secondary);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('功能'),
            const SizedBox(width: AppSpacing.sm),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final info = snapshot.data!;
                return Text(
                  'v${info.version}+${info.buildNumber}',
                  style: mutedStyle,
                );
              },
            ),
          ],
        ),
      ),
      body: ListView.separated(
        itemCount: features.length,
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
        itemBuilder: (context, index) {
          final feature = features[index];
          final bool limited = feature.support == PlatformSupport.limited;
          final String subtitle = limited
              ? '${feature.subtitle}（${feature.limitedNote ?? '当前平台功能受限'}）'
              : feature.subtitle;
          return ListTile(
            leading: Icon(feature.icon),
            title: Text(feature.title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: feature.builder),
              );
            },
          );
        },
      ),
    );
  }
}

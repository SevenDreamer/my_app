//! 功能页：功能列表（底部导航「功能」tab 的内容）
//!
//! 功能清单来自注册表（feature_registry.dart），
//! 按当前平台能力过滤展示：不支持的隐藏，受限的标注说明。
import 'package:flutter/material.dart';

import '../design/widgets/app_app_bar.dart';
import '../design/widgets/app_list_tile.dart';
import 'feature_registry.dart';

/// 功能页：功能列表（底部导航「功能」tab 的内容）。
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 当前平台不支持的功能不展示；受限功能在副标题标注
    final features = kFeatures
        .where((f) => f.support != PlatformSupport.none)
        .toList(growable: false);

    return Scaffold(
      appBar: const AppAppBar(title: '功能'),
      body: ListView.builder(
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          final bool limited = feature.support == PlatformSupport.limited;
          final String subtitle = limited
              ? '${feature.subtitle}（${feature.limitedNote ?? '当前平台功能受限'}）'
              : feature.subtitle;
          return AppListTile(
            icon: feature.icon,
            title: feature.title,
            subtitle: subtitle,
            showDivider: index != features.length - 1,
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

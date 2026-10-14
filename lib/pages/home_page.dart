import 'package:flutter/material.dart';

import 'robot_eye_page.dart';

/// 单个功能入口的描述
class _FeatureEntry {
  const _FeatureEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}

/// 主界面：空白主页 + 功能列表。
/// 后续新功能往 [_features] 里追加一条即可。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<_FeatureEntry> _features = [
    _FeatureEntry(
      icon: Icons.visibility_outlined,
      title: '机器人眼睛',
      subtitle: '表情 · 注视 · LED 眼睛动画',
      page: const RobotEyePage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('功能')),
      body: ListView.separated(
        itemCount: _features.length,
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
        itemBuilder: (context, index) {
          final feature = _features[index];
          return ListTile(
            leading: Icon(feature.icon),
            title: Text(feature.title),
            subtitle: Text(feature.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => feature.page),
              );
            },
          );
        },
      ),
    );
  }
}

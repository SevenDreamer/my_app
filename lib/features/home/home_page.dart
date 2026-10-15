import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../notes/notes_list_page.dart';
import '../robot_eyes/robot_eye_page.dart';

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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 版本信息从 pubspec.yaml 读取（version: 1.0.0+1），后续升级逻辑也基于它
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  static const List<_FeatureEntry> _features = [
    _FeatureEntry(
      icon: Icons.visibility_outlined,
      title: '机器人眼睛',
      subtitle: '表情 · 注视 · LED 眼睛动画',
      page: RobotEyePage(),
    ),
    _FeatureEntry(
      icon: Icons.edit_note,
      title: '记事本',
      subtitle: '记录想法与需求',
      page: NotesListPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context)
              .textTheme
              .bodySmall
              ?.color
              ?.withValues(alpha: 0.6),
        );
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('功能'),
            const SizedBox(width: 10),
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

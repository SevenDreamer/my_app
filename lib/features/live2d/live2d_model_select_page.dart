//! 模型选择页（设置 → 功能 → 模型选择）——B 样式模型列表
import 'package:flutter/material.dart';
import '../../design/widgets/app_toast.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/live2d_models.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_list_tile.dart';
import '../../design/widgets/app_header.dart';

class Live2dModelSelectPage extends StatelessWidget {
  const Live2dModelSelectPage({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: '模型选择',
        actions: [
          // 导入模型入口：底部弹出选择（本地导入/在线搜索）
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 18),
            onPressed: () => _showImportSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE4E4E7)),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < live2dModels.length; i++)
                  _ModelRow(
                    model: live2dModels[i],
                    selected: i == currentIndex,
                    onTap: () {
                      onSelect(i);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 导入方式选择（底部弹出）：本地导入 / 在线搜索
Future<void> _showImportSheet(BuildContext context) async {
  final choice = await showShadSheet<String>(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (ctx) => const ShadSheet(
      title: Text('导入模型'),
      description: Text('选择添加模型的方式'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ImportOption(
            icon: LucideIcons.fileUp,
            title: '本地导入',
            subtitle: '从文件中选择 .zip 模型包',
            value: 'local',
          ),
          _ImportOption(
            icon: LucideIcons.search,
            title: '在线搜索',
            subtitle: '从模型库查找并下载（规划中）',
            value: 'online',
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  AppToast.show(
    context,
    choice == 'local'
        ? '本地导入开发中——支持自定义 .zip 模型包'
        : '在线模型库开发中——敬请期待',
  );
}

/// 导入方式选项（AppListTile 自带 Material 层——shadcn 弹层里可用）
class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final ModelDef model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      iconLabel: model.label.substring(0, 1),
      title: model.label,
      subtitle: model.description,
      trailing: selected ? const Icon(LucideIcons.check, size: 16) : null,
      onTap: onTap,
    );
  }
}

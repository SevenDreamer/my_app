//! 模型选择页（设置 → 功能 → 模型选择）——B 样式模型列表
//!
//! 模型资产按需下载（包内不内置，见 data/services/model_downloader.dart）：
//! 点未下载的模型 → 自动下载（带进度）→ 完成后自动选中回舞台；
//! 点已下载的模型 → 直接选中。
import 'package:flutter/material.dart';
import '../../design/widgets/app_toast.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/live2d_models.dart';
import '../../data/services/model_downloader.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_list_tile.dart';
import '../../design/widgets/app_header.dart';

class Live2dModelSelectPage extends StatefulWidget {
  const Live2dModelSelectPage({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  State<Live2dModelSelectPage> createState() => _Live2dModelSelectPageState();
}

class _Live2dModelSelectPageState extends State<Live2dModelSelectPage> {
  final _downloader = ModelDownloader();

  /// 模型下载状态：id → 已下载；null 值=查询中
  final Map<String, bool> _downloaded = {};

  /// 下载中的模型 id → 进度 0-1
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    for (final m in live2dModels) {
      final ok = await _downloader.isDownloaded(m);
      if (!mounted) return;
      setState(() => _downloaded[m.id] = ok);
    }
  }

  /// 点行：已下载→选中；未下载→下载（完成后自动选中）
  Future<void> _onTap(int index) async {
    final model = live2dModels[index];
    if (_downloaded[model.id] == true) {
      widget.onSelect(index);
      Navigator.of(context).pop();
      return;
    }
    if (_progress.containsKey(model.id)) return; // 已在下载

    setState(() => _progress[model.id] = 0);
    try {
      await _downloader.download(model, onProgress: (p) {
        if (mounted) setState(() => _progress[model.id] = p);
      });
      if (!mounted) return;
      setState(() {
        _progress.remove(model.id);
        _downloaded[model.id] = true;
      });
      widget.onSelect(index);
      Navigator.of(context).pop();
    } on ModelDownloadException catch (e) {
      if (!mounted) return;
      setState(() => _progress.remove(model.id));
      AppToast.show(context, e.message);
    }
  }

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
                    selected: i == widget.currentIndex,
                    downloaded: _downloaded[live2dModels[i].id] ?? false,
                    progress: _progress[live2dModels[i].id],
                    onTap: () => _onTap(i),
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
    choice == 'local' ? '本地导入开发中——支持自定义 .zip 模型包' : '在线模型库开发中——敬请期待',
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
    required this.downloaded,
    required this.progress,
    required this.onTap,
  });

  final ModelDef model;
  final bool selected;
  final bool downloaded;

  /// 下载中进度 0-1；null = 未在下载
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 副标题：描述 + 体积/状态
    final sizeMb = model.zipSize == null
        ? ''
        : '${(model.zipSize! / 1024 / 1024).toStringAsFixed(1)}MB';
    final String stateText;
    final Widget? trailing;
    if (progress != null) {
      stateText = '下载中 ${(progress! * 100).toStringAsFixed(0)}%';
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress,
        ),
      );
    } else if (downloaded) {
      stateText = '已下载';
      trailing = selected ? const Icon(LucideIcons.check, size: 16) : null;
    } else {
      stateText = '未下载 · $sizeMb';
      trailing = const Icon(LucideIcons.fileUp, size: 16);
    }

    return AppListTile(
      iconLabel: model.label.substring(0, 1),
      title: model.label,
      subtitle: '${model.description} · $stateText',
      trailing: trailing,
      onTap: onTap,
    );
  }
}

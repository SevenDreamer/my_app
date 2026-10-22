//! 记事本列表页：纯 View（MVVM）
//!
//! 状态与数据访问全部来自 [NotesViewModel]，本页只做渲染与交互转发。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/models/note.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_list_tile.dart';
import 'note_edit_page.dart';
import 'notes_view_model.dart';

/// 记事本：需求 / 想法记录列表
class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  /// ViewModel：状态快照 + 命令的唯一来源（构造注入数据服务）
  late final NotesViewModel _viewModel = NotesViewModel()..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return hm;
    }
    return '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} $hm';
  }

  Future<void> _openEdit([Note? note]) async {
    // 编辑页共享同一 ViewModel：保存/删除后列表自动刷新，无需手动回读
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditPage(viewModel: _viewModel, note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: '记事本'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        child: const Icon(LucideIcons.plus),
      ),
      // 监听 ViewModel：任何命令完成后状态快照自动推送重建
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = _viewModel.notes;
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(
                      LucideIcons.filePlus2,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '还没有笔记\n点击右下角 + 记录你的想法',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            );
          }
          return ListView(
            children: [
              for (final note in notes)
                Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(LucideIcons.trash2,
                        color: AppColors.onPrimary),
                  ),
                  onDismissed: (direction) {
                    final id = note.id;
                    if (id != null) _viewModel.delete(id);
                    ShadSonner.of(context).show(
                      ShadToast(
                        id: DateTime.now().microsecondsSinceEpoch,
                        title: const Text('已删除'),
                      ),
                    );
                  },
                  child: AppListTile(
                    icon: LucideIcons.fileText,
                    title: note.title.isEmpty ? '（无标题）' : note.title,
                    subtitle: note.content,
                    trailing: Text(
                      _fmtTime(note.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    onTap: () => _openEdit(note),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

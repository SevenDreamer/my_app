//! 记事本：需求 / 想法记录列表
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_app_bar.dart';
import '../../design/widgets/app_list_tile.dart';
import 'note_database.dart';
import 'note.dart';
import 'note_edit_page.dart';

/// 记事本：需求 / 想法记录列表
class NotesListPage extends StatefulWidget {
  const NotesListPage({super.key});

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final notes = await NoteDatabase.instance.getAll();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NoteEditPage(note: note)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: '记事本'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        child: const Icon(LucideIcons.plus),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
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
                )
              : ListView(
                  children: [
                    for (final note in _notes)
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
                        onDismissed: (direction) async {
                          await NoteDatabase.instance.delete(note.id!);
                          _refresh();
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
                ),
    );
  }
}

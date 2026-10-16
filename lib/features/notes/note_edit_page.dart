//! 笔记编辑页（新建 / 编辑）：shadcn 输入组件 + 统一标题栏
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/widgets/app_app_bar.dart';
import 'note_database.dart';
import 'note.dart';

/// 笔记编辑页（新建 / 编辑）
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({super.key, this.note});

  /// 传入则为编辑模式，null 则为新建
  final Note? note;

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _saving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    // 空内容直接返回，不保存
    if (title.isEmpty && content.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    if (_isEditing) {
      await NoteDatabase.instance.update(
        widget.note!.copyWith(title: title, content: content, updatedAt: now),
      );
    } else {
      await NoteDatabase.instance.insert(
        Note(title: title, content: content, createdAt: now, updatedAt: now),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await NoteDatabase.instance.delete(widget.note!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(
        title: _isEditing ? '编辑笔记' : '新建笔记',
        actions: [
          if (_isEditing)
            ShadIconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: _delete,
            ),
          ShadButton.link(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ShadInput(
              controller: _titleCtrl,
              placeholder: const Text('标题'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ShadTextarea(
                controller: _contentCtrl,
                placeholder: const Text('写下你的想法或需求...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

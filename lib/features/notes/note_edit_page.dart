//! 笔记编辑页（新建 / 编辑）：纯 View（MVVM）
//!
//! 保存/删除经 [NotesViewModel] 下发，页面自身不接触数据服务。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/models/note.dart';
import '../../design/widgets/app_app_bar.dart';
import 'notes_view_model.dart';

/// 笔记编辑页（新建 / 编辑）
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({
    super.key,
    required this.viewModel,
    this.note,
  });

  /// 共享的 ViewModel（与列表页同一实例）
  final NotesViewModel viewModel;

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

  /// 保存：命令交给 ViewModel（内部处理空内容与时间戳）
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.viewModel.save(
      existing: widget.note,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// 删除：命令交给 ViewModel
  Future<void> _delete() async {
    await widget.viewModel.delete(widget.note!.id!);
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

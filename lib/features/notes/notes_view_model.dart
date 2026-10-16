//! 笔记 ViewModel：笔记板块的状态与命令的唯一入口
//!
//! MVVM 分层（官方架构技能）：View 只读状态快照 + 调用命令方法，
//! 数据访问（NoteDatabase）封装在此，View 不再直接触碰数据库。
import 'package:flutter/foundation.dart';

import '../../data/models/note.dart';
import '../../data/services/note_database.dart';

class NotesViewModel extends ChangeNotifier {
  /// 数据服务经构造注入（官方：依赖通过构造函数进入 ViewModel）
  NotesViewModel({NoteDatabase? database})
      : _database = database ?? NoteDatabase.instance;

  final NoteDatabase _database;

  List<Note> _notes = const [];
  bool _loading = true;

  /// 不可变状态快照
  List<Note> get notes => _notes;
  bool get loading => _loading;

  /// 加载全部笔记
  Future<void> load() async {
    final notes = await _database.getAll();
    _notes = List.unmodifiable(notes);
    _loading = false;
    notifyListeners();
  }

  /// 删除指定笔记
  Future<void> delete(int id) async {
    await _database.delete(id);
    await load();
  }

  /// 保存笔记：existing 非空为更新，否则为新建；
  /// 空内容不写库（由调用方决定是否关闭页面）。
  Future<void> save({
    Note? existing,
    required String title,
    required String content,
  }) async {
    if (title.isEmpty && content.isEmpty) return;
    final now = DateTime.now();
    if (existing != null) {
      await _database.update(
        existing.copyWith(title: title, content: content, updatedAt: now),
      );
    } else {
      await _database.insert(
        Note(title: title, content: content, createdAt: now, updatedAt: now),
      );
    }
    notifyListeners();
  }
}

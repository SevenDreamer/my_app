//! NotesViewModel 单测（测试安全网第一批，2026-11-10）。
//!
//! MVVM 标准样板的测试范式：假 NoteDatabase 注入，验证 load/delete/save
//! 的状态流转——页面层永不直连数据库（铁律），所以 VM 是逻辑测试的主战场。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/note.dart';
import 'package:my_app/data/services/note_database.dart';
import 'package:my_app/features/notes/notes_view_model.dart';

class FakeNoteDatabase implements NoteDatabase {
  final List<Note> store = [];
  int _seq = 1;

  @override
  Future<List<Note>> getAll() async => List.unmodifiable(store);

  @override
  Future<int> insert(Note note) async {
    final id = _seq++;
    store.add(Note(
      id: id,
      title: note.title,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    ));
    return id;
  }

  @override
  Future<void> update(Note note) async {
    store.removeWhere((n) => n.id == note.id);
    store.add(note);
  }

  @override
  Future<void> delete(int id) async {
    store.removeWhere((n) => n.id == id);
  }
}

Note _note(int id, String title) => Note(
      id: id,
      title: title,
      content: 'c',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('load：loading 流转 true→false，列表到位', () async {
    final db = FakeNoteDatabase()..store.add(_note(1, '第一条'));
    final vm = NotesViewModel(database: db);
    expect(vm.loading, isTrue);
    await vm.load();
    expect(vm.loading, isFalse);
    expect(vm.notes, hasLength(1));
    expect(vm.notes.first.title, '第一条');
    vm.dispose();
  });

  test('save 新条目：入库并刷新列表', () async {
    final db = FakeNoteDatabase();
    final vm = NotesViewModel(database: db);
    await vm.load();
    await vm.save(title: '标题', content: '内容');
    expect(db.store, hasLength(1));
    expect(vm.notes, hasLength(1));
    vm.dispose();
  });

  test('delete：移除并刷新列表', () async {
    final db = FakeNoteDatabase()
      ..store.add(_note(1, 'a'))
      ..store.add(_note(2, 'b'));
    final vm = NotesViewModel(database: db);
    await vm.load();
    await vm.delete(1);
    expect(vm.notes, hasLength(1));
    expect(vm.notes.first.id, 2);
    vm.dispose();
  });
}

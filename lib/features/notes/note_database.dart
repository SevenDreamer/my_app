import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'note.dart';

/// 笔记本地数据库（SQLite），单例模式
class NoteDatabase {
  NoteDatabase._();
  static final NoteDatabase instance = NoteDatabase._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = join(await getDatabasesPath(), 'notes.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE notes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        )
      '''),
    );
  }

  /// 全部笔记，按最近更新排序
  Future<List<Note>> getAll() async {
    final db = await _database;
    final maps = await db.query('notes', orderBy: 'updatedAt DESC');
    return maps.map(Note.fromMap).toList();
  }

  /// 新建，返回自增 id
  Future<int> insert(Note note) async {
    final db = await _database;
    return db.insert('notes', note.toMap()..remove('id'));
  }

  Future<void> update(Note note) async {
    final db = await _database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}

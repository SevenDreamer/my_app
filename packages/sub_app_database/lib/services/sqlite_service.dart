import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub_app_database/models/database_models.dart';
import 'package:sub_app_database/services/database_service.dart';

/// SQLite 服务实现
class SQLiteService extends DatabaseService {
  final DbConnectionConfig config;
  Database? _db;

  SQLiteService(this.config);

  @override
  Future<void> connect() async {
    if (config.filePath == null) {
      throw Exception('SQLite 数据库文件路径未指定');
    }

    // 初始化 FFI（桌面端需要）
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    _db = await databaseFactory.openDatabase(config.filePath!);
  }

  @override
  Future<void> disconnect() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    if (_db == null) await connect();

    // SQLite 只有一个数据库，获取所有表
    final tables = await getTables(config.databaseName ?? 'main');

    return [
      DatabaseInfo(
        name: config.databaseName ?? 'main',
        tables: tables,
      )
    ];
  }

  @override
  Future<List<TableInfo>> getTables(String databaseName) async {
    if (_db == null) await connect();

    final result = await _db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );

    List<TableInfo> tables = [];
    for (var row in result) {
      final tableName = row['name'] as String;
      final fields = await getFields(databaseName, tableName);

      // 获取行数
      final countResult =
          await _db!.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      final rowCount = countResult.first['count'] as int? ?? 0;

      tables.add(TableInfo(
        name: tableName,
        fields: fields,
        rowCount: rowCount,
      ));
    }

    return tables;
  }

  @override
  Future<List<FieldInfo>> getFields(
      String databaseName, String tableName) async {
    if (_db == null) await connect();

    final result = await _db!.rawQuery('PRAGMA table_info($tableName)');

    return result.map((row) {
      final name = row['name'] as String;
      final type = row['type'] as String? ?? 'TEXT';
      final isPrimaryKey = (row['pk'] as int) == 1;
      final isNullable = (row['notnull'] as int) == 0;

      return FieldInfo(
        name: name,
        type: type,
        isPrimaryKey: isPrimaryKey,
        isNullable: isNullable,
      );
    }).toList();
  }

  @override
  Future<bool> testConnection() async {
    try {
      await connect();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTableData(
      String databaseName, String tableName,
      {int limit = 100, int offset = 0}) async {
    if (_db == null) await connect();
    return await _db!
        .rawQuery('SELECT * FROM $tableName LIMIT $limit OFFSET $offset');
  }
}

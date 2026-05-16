import 'package:mysql1/mysql1.dart' hide DatabaseInfo;
import '../models/database_models.dart';
import 'database_service.dart';

/// MySQL 服务实现
class MySQLService extends DatabaseService {
  final DbConnectionConfig config;
  MySqlConnection? _connection;

  MySQLService(this.config);

  @override
  Future<void> connect() async {
    final settings = ConnectionSettings(
      host: config.host ?? 'localhost',
      port: config.port ?? 3306,
      user: config.username ?? 'root',
      password: config.password ?? '',
      db: config.databaseName,
    );

    _connection = await MySqlConnection.connect(settings);
  }

  @override
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    if (_connection == null) await connect();

    final result = await _connection!.query('SHOW DATABASES');

    List<DatabaseInfo> databases = [];
    for (var row in result) {
      final dbName = row[0] as String;
      if (dbName == 'information_schema' || dbName == 'mysql' || 
          dbName == 'performance_schema' || dbName == 'sys') {
        continue;
      }
      final tables = await getTables(dbName);
      databases.add(DatabaseInfo(name: dbName, tables: tables));
    }

    return databases;
  }

  @override
  Future<List<TableInfo>> getTables(String databaseName) async {
    if (_connection == null) await connect();

    await _connection!.query('USE `$databaseName`');

    final result = await _connection!.query('SHOW TABLES');

    List<TableInfo> tables = [];
    for (var row in result) {
      final tableName = row[0] as String;
      final fields = await getFields(databaseName, tableName);

      // 获取行数
      final countResult = await _connection!.query('SELECT COUNT(*) as count FROM `$tableName`');
      final rowCount = countResult.first[0] as int? ?? 0;

      tables.add(TableInfo(
        name: tableName,
        fields: fields,
        rowCount: rowCount,
      ));
    }

    return tables;
  }

  @override
  Future<List<FieldInfo>> getFields(String databaseName, String tableName) async {
    final result = await _connection!.query('''
      SELECT 
        column_name,
        data_type,
        is_nullable,
        column_default,
        column_key
      FROM information_schema.columns
      WHERE table_schema = '$databaseName' 
        AND table_name = '$tableName'
      ORDER BY ordinal_position
    ''');

    return result.map((row) {
      return FieldInfo(
        name: row[0] as String,
        type: row[1] as String,
        isNullable: row[2] == 'YES',
        defaultValue: row[3] as String?,
        isPrimaryKey: (row[4] as String).toUpperCase() == 'PRI',
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
  Future<List<Map<String, dynamic>>> getTableData(String databaseName, String tableName, {int limit = 100, int offset = 0}) async {
    if (_connection == null) await connect();
    await _connection!.query('USE `$databaseName`');

    final result = await _connection!.query('SELECT * FROM `$tableName` LIMIT $limit OFFSET $offset');

    return result.map((row) {
      final map = <String, dynamic>{};
      final fields = result.fields;
      for (var i = 0; i < fields.length; i++) {
        final fieldName = fields[i].name!;
        map[fieldName] = row[i];
      }
      return map;
    }).toList();
  }
}

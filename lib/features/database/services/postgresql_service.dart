import 'package:postgres/postgres.dart' hide DatabaseInfo;
import '../models/database_models.dart';
import 'database_service.dart';

/// PostgreSQL 服务实现
class PostgreSQLService extends DatabaseService {
  final DbConnectionConfig config;
  Connection? _connection;

  PostgreSQLService(this.config);

  @override
  Future<void> connect() async {
    final endpoint = Endpoint(
      host: config.host ?? 'localhost',
      port: config.port ?? 5432,
      database: config.databaseName ?? 'postgres',
      username: config.username ?? 'postgres',
      password: config.password ?? '',
    );

    _connection = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    if (_connection == null) await connect();

    // 获取所有数据库
    final result = await _connection!.execute(
      "SELECT datname FROM pg_database WHERE datistemplate = false",
    );

    List<DatabaseInfo> databases = [];
    for (var row in result) {
      final dbName = row[0] as String;
      final tables = await getTables(dbName);
      databases.add(DatabaseInfo(name: dbName, tables: tables));
    }

    return databases;
  }

  @override
  Future<List<TableInfo>> getTables(String databaseName) async {
    // 需要切换到目标数据库
    await disconnect();
    final endpoint = Endpoint(
      host: config.host ?? 'localhost',
      port: config.port ?? 5432,
      database: databaseName,
      username: config.username ?? 'postgres',
      password: config.password ?? '',
    );

    _connection = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );

    final result = await _connection!.execute('''
      SELECT tablename FROM pg_tables 
      WHERE schemaname = 'public'
    ''');

    List<TableInfo> tables = [];
    for (var row in result) {
      final tableName = row[0] as String;
      final fields = await getFields(databaseName, tableName);

      // 获取行数
      final countResult = await _connection!.execute(
        'SELECT COUNT(*) FROM "$tableName"',
      );
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
  Future<List<FieldInfo>> getFields(
      String databaseName, String tableName) async {
    final result = await _connection!.execute('''
      SELECT 
        c.column_name, 
        c.data_type, 
        c.is_nullable, 
        c.column_default,
        CASE WHEN pk.constraint_type = 'PRIMARY KEY' THEN true ELSE false END as is_primary
      FROM information_schema.columns c
      LEFT JOIN (
        SELECT kcu.column_name, tc.constraint_type
        FROM information_schema.key_column_usage kcu
        JOIN information_schema.table_constraints tc 
          ON kcu.constraint_name = tc.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND kcu.table_name = '$tableName'
      ) pk ON c.column_name = pk.column_name
      WHERE c.table_name = '$tableName'
        AND c.table_schema = 'public'
      ORDER BY c.ordinal_position
    ''');

    return result.map((row) {
      return FieldInfo(
        name: row[0] as String,
        type: row[1] as String,
        isNullable: row[2] == 'YES',
        defaultValue: row[3] as String?,
        isPrimaryKey: row[4] as bool? ?? false,
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
    if (_connection == null) await connect();

    // 切换到目标数据库
    await disconnect();
    final endpoint = Endpoint(
      host: config.host ?? 'localhost',
      port: config.port ?? 5432,
      database: databaseName,
      username: config.username ?? 'postgres',
      password: config.password ?? '',
    );
    _connection = await Connection.open(endpoint,
        settings: const ConnectionSettings(sslMode: SslMode.disable));

    final result = await _connection!.execute(
      'SELECT * FROM "$tableName" LIMIT $limit OFFSET $offset',
    );

    // 获取列名
    final columns = result.schema.columns.map((c) => c.columnName).toList();

    return result.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < columns.length; i++) {
        map[columns[i]!] = row[i];
      }
      return map;
    }).toList();
  }
}

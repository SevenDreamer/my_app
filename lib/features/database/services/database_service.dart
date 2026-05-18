import 'dart:convert';
import 'package:my_app/rust/ffi_manual.dart';
import '../models/database_models.dart';
import 'sqlite_service.dart';
import 'postgresql_service.dart';
import 'mysql_service.dart';
import 'mongodb_service.dart';

/// 数据库连接服务抽象类
abstract class DatabaseService {
  Future<void> connect();
  Future<void> disconnect();
  Future<List<DatabaseInfo>> getDatabases();
  Future<List<TableInfo>> getTables(String databaseName);
  Future<List<FieldInfo>> getFields(String databaseName, String tableName);
  Future<List<Map<String, dynamic>>> getTableData(
    String databaseName,
    String tableName, {
    int limit = 100,
    int offset = 0,
  });
  Future<bool> testConnection();
}

/// 混合服务：优先用 Rust FFI，未实现则降级到 Dart
class HybridDatabaseService extends DatabaseService {
  final DbConnectionConfig config;
  final RustDatabaseService _rust;
  final DatabaseService? _dartFallback;

  HybridDatabaseService(this.config)
      : _rust = RustDatabaseService(_configToJson(config)),
        _dartFallback = _createDartService(config);

  static String _configToJson(DbConnectionConfig c) => jsonEncode({
        'db_type': _dbTypeToString(c.type),
        'host': c.host,
        'port': c.port,
        'username': c.username,
        'password': c.password,
        'database_name': c.databaseName,
        'file_path': c.filePath,
      });

  static String _dbTypeToString(DbType type) => switch (type) {
        DbType.sqlite => 'sqlite',
        DbType.mysql => 'mysql',
        DbType.postgresql => 'postgresql',
        DbType.mongodb => 'mongodb',
      };

  static DatabaseService _createDartService(DbConnectionConfig c) => switch (c.type) {
        DbType.sqlite => SQLiteService(c),
        DbType.mysql => MySQLService(c),
        DbType.postgresql => PostgreSQLService(c),
        DbType.mongodb => MongoDBService(c),
      };

  @override
  Future<bool> testConnection() async {
    final rustOk = await _rust.testConnection();
    if (rustOk) return true;
    if (_dartFallback != null) return await _dartFallback.testConnection();
    return false;
  }

  @override
  Future<void> connect() async {
    try {
      await _rust.connect();
    } catch (_) {
      if (_dartFallback != null) await _dartFallback.connect();
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _rust.disconnect();
    } catch (_) {
      if (_dartFallback != null) await _dartFallback.disconnect();
    }
  }

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    try {
      return await _rust.getDatabases();
    } catch (_) {
      if (_dartFallback != null) return await _dartFallback.getDatabases();
      return [];
    }
  }

  @override
  Future<List<TableInfo>> getTables(String databaseName) async {
    try {
      final result = await _rust.getTables(databaseName);
      if (result.isNotEmpty) return result;
      throw Exception('empty');
    } catch (_) {
      if (_dartFallback != null) return await _dartFallback.getTables(databaseName);
      return [];
    }
  }

  @override
  Future<List<FieldInfo>> getFields(
    String databaseName,
    String tableName,
  ) async {
    try {
      final result = await _rust.getFields(databaseName, tableName);
      if (result.isNotEmpty) return result;
      throw Exception('empty');
    } catch (_) {
      if (_dartFallback != null) return await _dartFallback.getFields(databaseName, tableName);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTableData(
    String databaseName,
    String tableName, {
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final result = await _rust.getTableData(
        databaseName,
        tableName,
        limit: limit,
        offset: offset,
      );
      if (result.isNotEmpty) return result;
      throw Exception('empty');
    } catch (_) {
      if (_dartFallback != null) {
        return await _dartFallback.getTableData(
          databaseName,
          tableName,
          limit: limit,
          offset: offset,
        );
      }
      return [];
    }
  }
}

/// 通过 Rust FFI 调用数据库操作（内部类）
class RustDatabaseService {
  final String _configJson;
  String? _connId;

  RustDatabaseService(this._configJson);

  Future<bool> testConnection() async {
    try {
      final result = CoreFFI.instance.dbTestConnection(_configJson);
      final json = jsonDecode(result) as Map<String, dynamic>;
      return json['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect() async {
    final result = CoreFFI.instance.dbConnect(_configJson);
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json['ok'] == true) {
      _connId = json['conn_id'] as String;
    } else {
      throw Exception(json['error'] ?? 'Rust db_connect failed');
    }
  }

  Future<void> disconnect() async {
    if (_connId != null) {
      CoreFFI.instance.dbDisconnect(_connId!);
      _connId = null;
    }
  }

  Future<List<DatabaseInfo>> getDatabases() async {
    if (_connId == null) throw Exception('Not connected');
    final result = CoreFFI.instance.dbGetDatabases(_connId!);
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw Exception(json['error'] ?? 'db_get_databases failed');
    }
    final data = json['data'] as List<dynamic>;
    return data.map((d) {
      final m = d as Map<String, dynamic>;
      return DatabaseInfo(
        name: m['name'] as String,
        tables: (m['tables'] as List<dynamic>? ?? []).map((t) {
          final tt = t as Map<String, dynamic>;
          return TableInfo(
            name: tt['name'] as String,
            fields: [],
            rowCount: tt['row_count'] as int? ?? 0,
          );
        }).toList(),
      );
    }).toList();
  }

  Future<List<TableInfo>> getTables(String databaseName) async {
    if (_connId == null) throw Exception('Not connected');
    final result = CoreFFI.instance.dbGetTables(_connId!, databaseName);
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw Exception(json['error'] ?? 'db_get_tables failed');
    }
    // Rust 侧未完整实现时返回空列表，触发降级
    return [];
  }

  Future<List<FieldInfo>> getFields(
    String databaseName,
    String tableName,
  ) async {
    if (_connId == null) throw Exception('Not connected');
    final result = CoreFFI.instance.dbGetFields(
      _connId!,
      databaseName,
      tableName,
    );
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw Exception(json['error'] ?? 'db_get_fields failed');
    }
    // Rust 侧未完整实现时抛出异常，触发降级
    throw Exception('db_get_fields: not yet fully implemented');
  }

  Future<List<Map<String, dynamic>>> getTableData(
    String databaseName,
    String tableName, {
    int limit = 100,
    int offset = 0,
  }) async {
    if (_connId == null) throw Exception('Not connected');
    final result = CoreFFI.instance.dbGetTableData(
      _connId!,
      databaseName,
      tableName,
      limit: limit,
      offset: offset,
    );
    final json = jsonDecode(result) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw Exception(json['error'] ?? 'db_get_table_data failed');
    }
    // Rust 侧未完整实现时抛出异常，触发降级
    throw Exception('db_get_table_data: not yet fully implemented');
  }
}

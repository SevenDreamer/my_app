import 'dart:async';
import 'package:mongo_dart/mongo_dart.dart' hide DatabaseInfo, Connection;
import '../models/database_models.dart';
import 'database_service.dart';

/// MongoDB 服务实现
class MongoDBService extends DatabaseService {
  final DbConnectionConfig config;
  Db? _db;

  MongoDBService(this.config);

  @override
  Future<void> connect() async {
    final connectionString = config.host != null
        ? 'mongodb://${config.username != null ? '${config.username}:${config.password}@' : ''}${config.host}:${config.port ?? 27017}/${config.databaseName ?? 'admin'}'
        : 'mongodb://localhost:27017/${config.databaseName ?? 'admin'}';

    _db = await Db.create(connectionString);
    await _db!.open();
  }

  @override
  Future<void> disconnect() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    if (_db == null) await connect();

    // MongoDB 获取所有集合（表）
    final tables = await getTables(config.databaseName ?? 'default');

    return [
      DatabaseInfo(
        name: config.databaseName ?? 'default',
        tables: tables,
      )
    ];
  }

  @override
  Future<List<TableInfo>> getTables(String databaseName) async {
    if (_db == null) await connect();

    final collections = await _db!.getCollectionNames();

    List<TableInfo> tables = [];
    for (var collectionName in collections.whereType<String>()) {
      final collection = _db!.collection(collectionName);
      final count = await collection.count();
      
      // MongoDB 是 schema-less，尝试从样本文档推断字段
      final sample = await collection.findOne();
      List<FieldInfo> fields = [];
      
      if (sample != null) {
        sample.forEach((key, value) {
          fields.add(FieldInfo(
            name: key,
            type: _inferType(value),
            isNullable: true,
          ));
        });
      }

      tables.add(TableInfo(
        name: collectionName,
        fields: fields,
        rowCount: count,
      ));
    }

    return tables;
  }

  @override
  Future<List<FieldInfo>> getFields(String databaseName, String tableName) async {
    if (_db == null) await connect();

    final collection = _db!.collection(tableName);
    final sample = await collection.findOne();
    
    if (sample == null) return [];

    List<FieldInfo> fields = [];
    sample.forEach((key, value) {
      fields.add(FieldInfo(
        name: key,
        type: _inferType(value),
        isNullable: true,
      ));
    });

    return fields;
  }

  /// 推断 MongoDB 字段类型
  String _inferType(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'string';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    if (value is ObjectId) return 'ObjectId';
    if (value is DateTime) return 'datetime';
    return 'unknown';
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
    if (_db == null) await connect();
    final collection = _db!.collection(tableName);
    final cursor = collection.find(where.skip(offset).limit(limit));
    return await cursor.toList();
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 数据库类型枚举
enum DbType {
  sqlite('SQLite', LucideIcons.database),
  mysql('MySQL', LucideIcons.database),
  postgresql('PostgreSQL', LucideIcons.database),
  mongodb('MongoDB', LucideIcons.database);

  final String displayName;
  final IconData icon;

  const DbType(this.displayName, this.icon);
}

/// 数据库连接配置
class DbConnectionConfig {
  final String id;
  final String name;
  final DbType type;
  final String? host;
  final int? port;
  final String? username;
  final String? password;
  final String? databaseName;
  final String? filePath; // SQLite 文件路径
  final DateTime lastConnected;

  DbConnectionConfig({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.port,
    this.username,
    this.password,
    this.databaseName,
    this.filePath,
    required this.lastConnected,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'databaseName': databaseName,
      'filePath': filePath,
      'lastConnected': lastConnected.toIso8601String(),
    };
  }

  /// 从 JSON 创建
  factory DbConnectionConfig.fromJson(Map<String, dynamic> json) {
    return DbConnectionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DbType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DbType.sqlite,
      ),
      host: json['host'] as String?,
      port: json['port'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      databaseName: json['databaseName'] as String?,
      filePath: json['filePath'] as String?,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
    );
  }
}

/// 数据库信息
class DatabaseInfo {
  final String name;
  final List<TableInfo> tables;

  DatabaseInfo({required this.name, required this.tables});
}

/// 表信息
class TableInfo {
  final String name;
  final List<FieldInfo> fields;
  final int rowCount;

  TableInfo({required this.name, required this.fields, this.rowCount = 0});
}

/// 字段信息
class FieldInfo {
  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool isNullable;
  final String? defaultValue;

  FieldInfo({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isNullable = true,
    this.defaultValue,
  });
}

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sub_app_database/models/database_models.dart';

/// 树节点类型
enum TreeNodeType {
  connection, // 连接节点
  database, // 数据库节点
  table, // 表节点
  folder, // 文件夹节点（如 Tables, Views, Functions）
  field, // 字段节点
}

/// 数据库树节点
class DbTreeNode {
  final String id;
  final String label;
  final TreeNodeType type;
  final IconData icon;
  final Color? iconColor;
  final DbConnectionConfig? connection;
  final DatabaseInfo? database;
  final TableInfo? table;
  final FieldInfo? field;
  DbTreeNode? parent;
  List<DbTreeNode> children;
  bool isExpanded;
  bool isSelected;
  bool isLoading;

  DbTreeNode({
    required this.id,
    required this.label,
    required this.type,
    required this.icon,
    this.iconColor,
    this.connection,
    this.database,
    this.table,
    this.field,
    this.parent,
    this.children = const [],
    this.isExpanded = false,
    this.isSelected = false,
    this.isLoading = false,
  });

  /// 创建连接节点
  factory DbTreeNode.connection(DbConnectionConfig config,
      {bool isConnected = false}) {
    return DbTreeNode(
      id: 'conn_${config.id}',
      label: config.name,
      type: TreeNodeType.connection,
      icon: LucideIcons.plug,
      iconColor: isConnected ? Colors.green : const Color(0xFF9E9E9E),
      connection: config,
      children: [],
    );
  }

  /// 创建数据库节点
  factory DbTreeNode.database(DatabaseInfo db) {
    return DbTreeNode(
      id: 'db_${db.name}',
      label: db.name,
      type: TreeNodeType.database,
      icon: LucideIcons.database,
      database: db,
      children: [],
    );
  }

  /// 创建文件夹节点（Tables, Views, Functions 等）
  factory DbTreeNode.folder(
      String name, IconData icon, List<DbTreeNode> children) {
    return DbTreeNode(
      id: 'folder_${name}_${DateTime.now().millisecondsSinceEpoch}',
      label: name,
      type: TreeNodeType.folder,
      icon: icon,
      children: children,
    );
  }

  /// 创建表节点
  factory DbTreeNode.table(TableInfo table) {
    return DbTreeNode(
      id: 'table_${table.name}',
      label: table.name,
      type: TreeNodeType.table,
      icon: LucideIcons.table,
      table: table,
      children: [],
    );
  }

  /// 创建字段节点
  factory DbTreeNode.field(FieldInfo field) {
    return DbTreeNode(
      id: 'field_${field.name}',
      label: field.name,
      type: TreeNodeType.field,
      icon: field.isPrimaryKey ? LucideIcons.key : LucideIcons.type,
      iconColor: field.isPrimaryKey ? Colors.amber : null,
      field: field,
      children: [],
    );
  }

  DbTreeNode copyWith({
    String? id,
    String? label,
    TreeNodeType? type,
    IconData? icon,
    Color? iconColor,
    DbConnectionConfig? connection,
    DatabaseInfo? database,
    TableInfo? table,
    FieldInfo? field,
    DbTreeNode? parent,
    List<DbTreeNode>? children,
    bool? isExpanded,
    bool? isSelected,
    bool? isLoading,
  }) {
    return DbTreeNode(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      connection: connection ?? this.connection,
      database: database ?? this.database,
      table: table ?? this.table,
      field: field ?? this.field,
      parent: parent ?? this.parent,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      isSelected: isSelected ?? this.isSelected,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

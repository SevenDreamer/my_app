import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/database_models.dart';
import 'db_tree_node.dart';

/// 数据库树节点构建器
/// 负责根据连接配置和数据库信息构建树节点
class DatabaseTreeBuilder {
  /// 构建完整的树节点列表
  static List<DbTreeNode> buildTreeNodes({
    required List<DbConnectionConfig> connections,
    DbConnectionConfig? currentConnection,
    required List<DatabaseInfo> databases,
    DbTreeNode? selectedNode,
  }) {
    final nodes = <DbTreeNode>[];

    for (final connection in connections) {
      final isConnected = currentConnection?.id == connection.id;
      final connNode =
          DbTreeNode.connection(connection, isConnected: isConnected);

      if (isConnected && databases.isNotEmpty) {
        // 已连接，展开数据库列表
        connNode.isExpanded = true;
        final dbChildren = <DbTreeNode>[];

        for (final db in databases) {
          final dbNode = DbTreeNode.database(db);
          dbNode.parent = connNode;

          // 添加文件夹节点（Tables, Views, Functions, Procedures）
          final folderChildren = <DbTreeNode>[];

          // Tables 文件夹
          if (db.tables.isNotEmpty) {
            final tableNodes = db.tables.map((t) {
              final tableNode = DbTreeNode.table(t);
              tableNode.parent = dbNode;
              // 为每个表添加字段子节点
              final fieldNodes = t.fields.map((f) {
                final fieldNode = DbTreeNode.field(f);
                fieldNode.parent = tableNode;
                return fieldNode;
              }).toList();
              tableNode.children = fieldNodes;
              return tableNode;
            }).toList();
            final tablesFolder =
                DbTreeNode.folder('Tables', LucideIcons.list, tableNodes);
            tablesFolder.parent = dbNode;
            folderChildren.add(tablesFolder);
          }

          // Views 文件夹（模拟）
          final viewsFolder = DbTreeNode.folder('Views', LucideIcons.eye, []);
          viewsFolder.parent = dbNode;
          folderChildren.add(viewsFolder);

          // Functions 文件夹（模拟）
          final functionsFolder =
              DbTreeNode.folder('Functions', LucideIcons.functionSquare, []);
          functionsFolder.parent = dbNode;
          folderChildren.add(functionsFolder);

          // Procedures 文件夹（模拟）
          final proceduresFolder =
              DbTreeNode.folder('Procedures', LucideIcons.settings, []);
          proceduresFolder.parent = dbNode;
          folderChildren.add(proceduresFolder);

          dbNode.children.addAll(folderChildren);
          dbChildren.add(dbNode);
        }

        connNode.children.addAll(dbChildren);
      }

      nodes.add(connNode);
    }

    return nodes;
  }
}

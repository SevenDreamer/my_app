import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/database_models.dart';
import 'db_tree_node.dart';
import 'db_tree_view.dart';
import 'database_tree_builder.dart';

/// 数据库树Widget
/// 封装了树的所有逻辑：节点构建、节点交互、状态管理
class DatabaseTreeWidget extends StatefulWidget {
  final List<DbConnectionConfig> connections;
  final DbConnectionConfig? currentConnection;
  final List<DatabaseInfo> databases;
  final void Function(DbConnectionConfig)? onConnectionTap;
  final void Function(DbTreeNode)? onNodeSelected;
  final void Function(DbTreeNode)? onNodeExpand;
  final void Function(DbTreeNode)? onNodeCollapse;
  final void Function(DbConnectionConfig)? onConnectionDelete;
  final void Function(DbConnectionConfig)? onConnectionRefresh;

  const DatabaseTreeWidget({
    super.key,
    required this.connections,
    this.currentConnection,
    required this.databases,
    this.onConnectionTap,
    this.onNodeSelected,
    this.onNodeExpand,
    this.onNodeCollapse,
    this.onConnectionDelete,
    this.onConnectionRefresh,
  });

  @override
  State<DatabaseTreeWidget> createState() => _DatabaseTreeWidgetState();
}

class _DatabaseTreeWidgetState extends State<DatabaseTreeWidget> {
  List<DbTreeNode> _treeNodes = [];

  @override
  void initState() {
    super.initState();
    _buildTreeNodes();
  }

  @override
  void didUpdateWidget(DatabaseTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connections != widget.connections ||
        oldWidget.currentConnection != widget.currentConnection ||
        oldWidget.databases != widget.databases) {
      _buildTreeNodes();
    }
  }

  /// 构建树节点
  void _buildTreeNodes() {
    setState(() {
      _treeNodes = DatabaseTreeBuilder.buildTreeNodes(
        connections: widget.connections,
        currentConnection: widget.currentConnection,
        databases: widget.databases,
      );
    });
  }

  /// 处理节点点击
  void _handleNodeTap(DbTreeNode node) {
    setState(() {
      // 清除之前的选择
      _clearSelection(_treeNodes);
      node.isSelected = true;
    });

    // 回调
    widget.onNodeSelected?.call(node);

    // 如果是连接节点，触发连接回调
    if (node.type == TreeNodeType.connection && node.connection != null) {
      widget.onConnectionTap?.call(node.connection!);
    }
  }

  /// 处理节点展开
  void _handleNodeExpand(DbTreeNode node) {
    setState(() {
      node.isExpanded = true;
    });
    widget.onNodeExpand?.call(node);

    // 如果是连接节点且未连接，触发连接
    if (node.type == TreeNodeType.connection && node.connection != null) {
      if (widget.currentConnection?.id != node.connection!.id) {
        widget.onConnectionTap?.call(node.connection!);
      }
    }
  }

  /// 处理节点折叠
  void _handleNodeCollapse(DbTreeNode node) {
    setState(() {
      node.isExpanded = false;
    });
    widget.onNodeCollapse?.call(node);
  }

  /// 处理连接删除
  void _handleNodeDelete(DbTreeNode node) {
    if (node.connection != null) {
      widget.onConnectionDelete?.call(node.connection!);
    }
  }

  /// 处理连接刷新
  void _handleNodeRefresh(DbTreeNode node) {
    if (node.connection != null) {
      widget.onConnectionRefresh?.call(node.connection!);
    }
  }

  /// 清除选择状态
  void _clearSelection(List<DbTreeNode> nodes) {
    for (final node in nodes) {
      node.isSelected = false;
      _clearSelection(node.children);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_treeNodes.isEmpty) {
      return _buildNoConnection();
    }

    return DbTreeView(
      nodes: _treeNodes,
      onNodeTap: _handleNodeTap,
      onNodeExpand: _handleNodeExpand,
      onNodeCollapse: _handleNodeCollapse,
      onNodeDelete: _handleNodeDelete,
      onNodeRefresh: _handleNodeRefresh,
    );
  }

  Widget _buildNoConnection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.database,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无数据库连接',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

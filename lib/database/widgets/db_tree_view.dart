import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:heroui_design_system/heroui_design_system.dart';

import 'db_tree_node.dart';

/// 数据库文件树视图
class DbTreeView extends StatefulWidget {
  final List<DbTreeNode> nodes;
  final Function(DbTreeNode)? onNodeTap;
  final Function(DbTreeNode)? onNodeExpand;
  final Function(DbTreeNode)? onNodeCollapse;
  final Function(DbTreeNode)? onNodeDelete;
  final Function(DbTreeNode)? onNodeRefresh;
  final Function(DbTreeNode)? onNodeEdit;
  final double indent;
  final EdgeInsets padding;

  const DbTreeView({
    super.key,
    required this.nodes,
    this.onNodeTap,
    this.onNodeExpand,
    this.onNodeCollapse,
    this.onNodeDelete,
    this.onNodeRefresh,
    this.onNodeEdit,
    this.indent = 20,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  @override
  State<DbTreeView> createState() => _DbTreeViewState();
}

class _DbTreeViewState extends State<DbTreeView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: widget.nodes.length,
      itemBuilder: (context, index) {
        return _buildNode(widget.nodes[index], 0);
      },
    );
  }

  Widget _buildNode(DbTreeNode node, int depth) {
    final hasChildren = node.children.isNotEmpty;
    final isExpandable = hasChildren || node.type == TreeNodeType.connection || node.type == TreeNodeType.database || node.type == TreeNodeType.table;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNodeItem(node, depth, isExpandable),
        if (node.isExpanded && hasChildren)
          ...node.children.map((child) => _buildNode(child, depth + 1)),
      ],
    );
  }

  Widget _buildNodeItem(DbTreeNode node, int depth, bool isExpandable) {
    final isConnection = node.type == TreeNodeType.connection;
    final isDatabase = node.type == TreeNodeType.database;
    final isFolder = node.type == TreeNodeType.folder;

    return InkWell(
      onTap: () {
        if (isExpandable) {
          setState(() {
            node.isExpanded = !node.isExpanded;
          });
          if (node.isExpanded) {
            widget.onNodeExpand?.call(node);
          } else {
            widget.onNodeCollapse?.call(node);
          }
        }
        widget.onNodeTap?.call(node);
      },
      child: Container(
        height: 32,
        padding: EdgeInsets.only(left: 8 + depth * widget.indent, right: 8),
        decoration: BoxDecoration(
          color: node.isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // 展开/折叠箭头
            if (isExpandable)
              SizedBox(
                width: 20,
                child: AnimatedRotation(
                  turns: node.isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              )
            else
              const SizedBox(width: 20),

            // 图标
            Icon(
              node.icon,
              size: _getIconSize(node.type),
              color: node.iconColor ?? _getIconColor(node.type),
            ),
            const SizedBox(width: 8),

            // 标签
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      node.label,
                      style: HeroUiTypography.bodyXs.copyWith(
                        color: node.isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: node.isSelected || isConnection
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 显示表的行数
                  if (node.type == TreeNodeType.table && node.table != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${node.table!.rowCount})',
                      style: HeroUiTypography.bodyXs.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 连接状态指示器
            if (isConnection && node.iconColor == Colors.green)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

            // 加载指示器
            if (node.isLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

            // 操作按钮（悬停时显示）
            if (isConnection)
              _buildConnectionActions(node),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionActions(DbTreeNode node) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: LucideIcons.refreshCw,
          onTap: () => widget.onNodeRefresh?.call(node),
          tooltip: '刷新',
        ),
        _buildActionButton(
          icon: LucideIcons.pencil,
          onTap: () => widget.onNodeEdit?.call(node),
          tooltip: '编辑',
        ),
        _buildActionButton(
          icon: LucideIcons.trash2,
          onTap: () => widget.onNodeDelete?.call(node),
          tooltip: '删除',
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 12,
            color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  double _getIconSize(TreeNodeType type) {
    switch (type) {
      case TreeNodeType.connection:
        return 16;
      case TreeNodeType.database:
        return 15;
      case TreeNodeType.folder:
        return 14;
      case TreeNodeType.table:
        return 14;
      case TreeNodeType.field:
        return 12;
    }
  }

  Color _getIconColor(TreeNodeType type) {
    final theme = Theme.of(context);
    switch (type) {
      case TreeNodeType.connection:
        return theme.colorScheme.primary;
      case TreeNodeType.database:
        return Colors.blue;
      case TreeNodeType.folder:
        return theme.colorScheme.onSurface.withOpacity(0.6);
      case TreeNodeType.table:
        return Colors.orange;
      case TreeNodeType.field:
        return theme.colorScheme.onSurface.withOpacity(0.5);
    }
  }
}

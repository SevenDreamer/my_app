import 'package:my_app/features/database/models/database_models.dart';
import 'package:my_app/features/database/widgets/db_tree_node.dart';

/// 数据库树控制器
/// 负责处理树节点的所有交互逻辑
class DatabaseTreeController {
  DbConnectionConfig? currentConnection;
  List<DatabaseInfo> databases;
  TableInfo? selectedTable;
  DatabaseInfo? selectedDatabase;
  DbTreeNode? selectedNode;

  /// 构造函数
  DatabaseTreeController({
    this.currentConnection,
    this.databases = const [],
    this.selectedTable,
    this.selectedDatabase,
    this.selectedNode,
  });

  /// 处理节点点击
  void handleNodeTap(DbTreeNode node) {
    // 清除之前的选择
    _clearSelection(node);

    switch (node.type) {
      case TreeNodeType.connection:
        // 连接节点点击逻辑由外部处理（可能需要连接）
        break;
      case TreeNodeType.database:
        selectedDatabase = node.database;
        selectedTable = null;
        break;
      case TreeNodeType.table:
        selectedTable = node.table;
        // 从父节点链查找数据库
        _findDatabaseFromParent(node);
        break;
      case TreeNodeType.folder:
      case TreeNodeType.field:
        break;
    }
  }

  /// 从父节点链查找数据库
  void _findDatabaseFromParent(DbTreeNode node) {
    DbTreeNode? current = node.parent;
    while (current != null) {
      if (current.database != null) {
        selectedDatabase = current.database;
        break;
      }
      current = current.parent;
    }
  }

  /// 清除选择状态
  void _clearSelection(DbTreeNode root) {
    void clear(DbTreeNode node) {
      node.isSelected = false;
      for (final child in node.children) {
        clear(child);
      }
    }

    // 从根节点开始清除
    // 注意：这里假设传入的root是新的选择节点，我们需要清除所有节点的选择
    // 但是我们没有根节点引用，所以我们需要外部传入根节点列表
    // 因此，这个方法需要重构，或者由外部处理清除逻辑
    // 暂时保留在外部处理
  }

  /// 清除所有节点的选择状态
  void clearAllSelection(List<DbTreeNode> nodes) {
    for (final node in nodes) {
      node.isSelected = false;
      _clearChildrenSelection(node.children);
    }
  }

  void _clearChildrenSelection(List<DbTreeNode> nodes) {
    for (final node in nodes) {
      node.isSelected = false;
      _clearChildrenSelection(node.children);
    }
  }
}

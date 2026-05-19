import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/database_models.dart';
import '../services/database_service.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/database_tree_widget.dart';
import '../widgets/db_tree_node.dart';

/// 数据库管理主界面
class DatabaseManagerScreen extends StatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  State<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends State<DatabaseManagerScreen> {
  List<DbConnectionConfig> _savedConnections = [];
  DbConnectionConfig? _currentConnection;
  List<DatabaseInfo> _databases = [];
  DatabaseInfo? _selectedDatabase;
  TableInfo? _selectedTable;
  bool _showConnectionList = true;
  bool _isConnecting = false;
  String? _connectionError;

  // 表数据相关
  List<Map<String, dynamic>> _tableData = [];
  bool _isLoadingTableData = false;
  String? _tableDataError;
  int _currentPage = 0;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  /// 加载保存的连接
  Future<void> _loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final connectionsJson = prefs.getStringList('db_connections') ?? [];

    setState(() {
      _savedConnections = connectionsJson
          .map((json) => DbConnectionConfig.fromJson(
              jsonDecode(json) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    });
  }

  /// 处理节点选择
  void _handleNodeSelected(DbTreeNode node) async {
    setState(() {
      _selectedTable = null;
      _tableData = [];
      _tableDataError = null;
    });

    switch (node.type) {
      case TreeNodeType.connection:
        break;
      case TreeNodeType.database:
        setState(() {
          _selectedDatabase = node.database;
        });
        break;
      case TreeNodeType.table:
        setState(() {
          _selectedTable = node.table;
          // 从父节点链查找数据库
          DbTreeNode? current = node.parent;
          while (current != null) {
            if (current.database != null) {
              _selectedDatabase = current.database;
              break;
            }
            current = current.parent;
          }
          _showConnectionList = false;
        });
        // 加载表数据
        if (_selectedDatabase != null && _selectedTable != null) {
          await _loadTableData();
        }
        break;
      case TreeNodeType.folder:
      case TreeNodeType.field:
        break;
    }
  }

  /// 加载表数据
  Future<void> _loadTableData() async {
    if (_currentConnection == null ||
        _selectedDatabase == null ||
        _selectedTable == null) return;

    setState(() {
      _isLoadingTableData = true;
      _tableDataError = null;
    });

    try {
      DatabaseService service = _createService(_currentConnection!);
      await service.connect();
      final data = await service.getTableData(
        _selectedDatabase!.name,
        _selectedTable!.name,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );
      await service.disconnect();

      setState(() {
        _tableData = data;
        _isLoadingTableData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTableData = false;
        _tableDataError = e.toString();
      });
    }
  }

  /// 创建数据库服务
  /// 使用混合模式：优先 Rust FFI，未实现则降级到 Dart
  DatabaseService _createService(DbConnectionConfig config) {
    return HybridDatabaseService(config);
  }

  /// 处理连接删除
  Future<void> _handleConnectionDelete(DbConnectionConfig config) async {
    await _deleteConnection(config.id);
  }

  /// 处理连接刷新
  Future<void> _handleConnectionRefresh(DbConnectionConfig config) async {
    await _connectToDatabase(config);
  }

  /// 保存连接配置
  Future<void> _saveConnection(DbConnectionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    _savedConnections.removeWhere((c) => c.id == config.id);
    _savedConnections.insert(0, config);
    if (_savedConnections.length > 20) {
      _savedConnections = _savedConnections.sublist(0, 20);
    }
    final connectionsJson =
        _savedConnections.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('db_connections', connectionsJson);
    setState(() {});
  }

  /// 删除连接
  Future<void> _deleteConnection(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _savedConnections.removeWhere((c) => c.id == id);
    final connectionsJson =
        _savedConnections.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('db_connections', connectionsJson);
    if (_currentConnection?.id == id) {
      setState(() {
        _currentConnection = null;
        _databases = [];
        _selectedDatabase = null;
        _selectedTable = null;
        _tableData = [];
      });
    }
    setState(() {});
  }

  /// 连接数据库（真实）
  Future<void> _connectToDatabase(DbConnectionConfig config) async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
      _selectedTable = null;
      _tableData = [];
    });

    try {
      DatabaseService service = _createService(config);

      final success = await service.testConnection();

      if (!success) {
        throw Exception('无法连接到数据库，请检查连接配置');
      }

      await service.connect();
      final databases = await service.getDatabases();

      setState(() {
        _currentConnection = config;
        _databases = databases;
        _selectedDatabase = null;
        _selectedTable = null;
        _showConnectionList = false;
        _isConnecting = false;
      });

      await service.disconnect();
      _saveConnection(config);
      setState(() {});
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _connectionError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $_connectionError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
      },
    );
  }

  /// 桌面端布局
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSidebar(),
        const VerticalDivider(width: 1),
        Expanded(child: _buildContent()),
      ],
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout() {
    if (_showConnectionList || _currentConnection == null) {
      return _buildMobileConnectionList();
    }
    return _buildContent();
  }

  /// 移动端连接列表
  Widget _buildMobileConnectionList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('数据库连接', style: HeroUiTypography.heading4),
              const Spacer(),
              IconButton(
                icon: const Icon(LucideIcons.plus),
                onPressed: _showConnectionDialog,
                tooltip: '新建连接',
              ),
            ],
          ),
        ),
        Expanded(
          child: _savedConnections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.database,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无数据库连接',
                        style: HeroUiTypography.bodySm.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _savedConnections.length,
                  itemBuilder: (context, index) =>
                      _buildConnectionListItem(_savedConnections[index]),
                ),
        ),
      ],
    );
  }

  /// 连接列表项（移动端）
  Widget _buildConnectionListItem(DbConnectionConfig connection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: HeroUiCard(
        borderRadius: 12,
        showShadow: false,
        borderColor: Theme.of(context).dividerColor.withOpacity(0.3),
        body: ListTile(
          leading: Icon(connection.type.icon),
          title: Text(connection.name, style: HeroUiTypography.bodySmMedium),
          subtitle: Text(
            '${connection.type.displayName} • ${connection.lastConnected.toString().substring(0, 10)}',
            style: HeroUiTypography.bodyXs.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteConnection(connection.id);
            },
          ),
          onTap: () => _connectToDatabase(connection),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// 左侧边栏
  Widget _buildSidebar() {
    return Container(
      width: 300,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部工具栏
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('DATABASE',
                    style: HeroUiTypography.bodyXsMedium.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      letterSpacing: 1,
                    )),
                const Spacer(),
                _buildToolbarButton(
                  icon: LucideIcons.settings,
                  onTap: () {},
                  tooltip: '设置',
                ),
                _buildToolbarButton(
                  icon: LucideIcons.history,
                  onTap: () {},
                  tooltip: '历史',
                ),
                _buildToolbarButton(
                  icon: LucideIcons.refreshCw,
                  onTap: () {
                    if (_currentConnection != null) {
                      _connectToDatabase(_currentConnection!);
                    }
                  },
                  tooltip: '刷新',
                ),
                _buildToolbarButton(
                  icon: LucideIcons.plus,
                  onTap: _showConnectionDialog,
                  tooltip: '新建连接',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 使用 DatabaseTreeWidget
          Expanded(
            child: DatabaseTreeWidget(
              connections: _savedConnections,
              currentConnection: _currentConnection,
              databases: _databases,
              onConnectionTap: _connectToDatabase,
              onNodeSelected: _handleNodeSelected,
              onConnectionDelete: _handleConnectionDelete,
              onConnectionRefresh: _handleConnectionRefresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  /// 右侧内容区
  Widget _buildContent() {
    if (_isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在连接数据库...', style: HeroUiTypography.bodySm),
          ],
        ),
      );
    }

    if (_currentConnection == null) return _buildWelcomeScreen();
    if (_selectedTable == null) return _buildDatabaseOverview();
    return _buildTableDataView();
  }

  /// 欢迎界面
  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.database,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          const Text('数据库管理', style: HeroUiTypography.heading3),
          const SizedBox(height: 8),
          Text(
            '连接数据库以开始管理',
            style: HeroUiTypography.bodySm.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 32),
          HeroUiButton(
            label: '新建连接',
            onPressed: _showConnectionDialog,
            variant: HeroUiButtonVariant.primary,
            size: HeroUiButtonSize.lg,
            leading: const Icon(LucideIcons.plus, size: 18),
          ),
        ],
      ),
    );
  }

  /// 数据库概览
  Widget _buildDatabaseOverview() {
    if (_selectedDatabase == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.table,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '选择一个表查看数据',
              style: HeroUiTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_selectedDatabase!.name, style: HeroUiTypography.heading3),
              const SizedBox(width: 12),
              Text(
                '${_selectedDatabase!.tables.length} 个表',
                style: HeroUiTypography.bodySm.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    (constraints.maxWidth / 240).floor().clamp(1, 4);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _selectedDatabase!.tables.length,
                  itemBuilder: (context, index) =>
                      _buildTableCard(_selectedDatabase!.tables[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 表卡片
  Widget _buildTableCard(TableInfo table) {
    return HeroUiCard(
      borderRadius: 12,
      showShadow: true,
      onTap: () async {
        setState(() {
          _selectedTable = table;
          _showConnectionList = false;
        });
        await _loadTableData();
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.table,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            table.name,
            style: HeroUiTypography.bodySmMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${table.fields.length} 个字段 • ${table.rowCount} 条数据',
            style: HeroUiTypography.bodyXs.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  /// 表数据视图
  Widget _buildTableDataView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width < 600)
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () => setState(() => _selectedTable = null),
                ),
              Icon(LucideIcons.table,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(_selectedTable!.name, style: HeroUiTypography.heading4),
              const SizedBox(width: 12),
              Text(
                '${_selectedTable!.rowCount} 条数据',
                style: HeroUiTypography.bodyXs.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              // 刷新按钮
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: _isLoadingTableData ? null : _loadTableData,
                tooltip: '刷新数据',
              ),
              // 字段信息按钮
              IconButton(
                icon: const Icon(LucideIcons.info, size: 18),
                onPressed: () => _showFieldInfo(),
                tooltip: '查看字段信息',
              ),
            ],
          ),
        ),
        // 数据表格
        Expanded(
          child: _buildDataTable(),
        ),
        // 分页控件
        if (_selectedTable!.rowCount > _pageSize) _buildPagination(),
      ],
    );
  }

  /// 数据表格
  Widget _buildDataTable() {
    if (_isLoadingTableData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tableDataError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle,
                size: 48, color: Colors.red.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('加载失败', style: HeroUiTypography.bodySmMedium),
            const SizedBox(height: 8),
            Text(_tableDataError!,
                style: HeroUiTypography.bodyXs, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            HeroUiButton(
              label: '重试',
              onPressed: _loadTableData,
              variant: HeroUiButtonVariant.secondary,
              size: HeroUiButtonSize.sm,
            ),
          ],
        ),
      );
    }

    if (_tableData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.inbox,
                size: 48,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('表中没有数据', style: HeroUiTypography.bodySm),
          ],
        ),
      );
    }

    // 获取列名
    final columns = _selectedTable!.fields.map((f) => f.name).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.5),
          ),
          headingTextStyle: HeroUiTypography.bodyXsMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dataTextStyle: HeroUiTypography.bodyXs,
          columnSpacing: 16,
          horizontalMargin: 16,
          columns: columns.map((col) {
            final field = _selectedTable!.fields.firstWhere(
              (f) => f.name == col,
              orElse: () => _selectedTable!.fields.first,
            );
            return DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (field.isPrimaryKey) ...[
                    const Icon(LucideIcons.key, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      col,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              tooltip: '${field.type}${field.isNullable ? '' : ' NOT NULL'}',
            );
          }).toList(),
          rows: _tableData.map((row) {
            return DataRow(
              cells: columns.map((col) {
                final value = row[col];
                return DataCell(
                  Text(
                    _formatCellValue(value),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 格式化单元格值
  String _formatCellValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{${value.length} keys}';
    return value.toString();
  }

  /// 分页控件
  Widget _buildPagination() {
    final totalPages = (_selectedTable!.rowCount / _pageSize).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadTableData();
                  }
                : null,
          ),
          Text(
            '第 ${_currentPage + 1} / $totalPages 页',
            style: HeroUiTypography.bodyXs,
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadTableData();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// 显示字段信息对话框
  void _showFieldInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_selectedTable!.name} - 字段信息'),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _selectedTable!.fields.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildFieldItem(_selectedTable!.fields[index]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 字段项
  Widget _buildFieldItem(FieldInfo field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          if (field.isPrimaryKey)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PK',
                style: HeroUiTypography.navLabel.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else
            const SizedBox(width: 32),
          const SizedBox(width: 12),
          Expanded(
              child: Text(field.name, style: HeroUiTypography.bodyXsMedium)),
          Text(
            field.type,
            style: HeroUiTypography.bodyXs.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          if (!field.isNullable)
            Text(
              'NOT NULL',
              style: HeroUiTypography.navLabel.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
        ],
      ),
    );
  }

  /// 显示连接对话框
  void _showConnectionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => ConnectionDialog(
        onConnect: (config) {
          _connectToDatabase(config);
        },
        onSave: (config) {
          _saveConnection(config);
        },
      ),
    );
  }
}

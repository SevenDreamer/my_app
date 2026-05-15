import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/database_models.dart';
import '../services/sqlite_service.dart' show SQLiteService;
import '../services/postgresql_service.dart' show PostgreSQLService;
import '../services/mysql_service.dart' show MySQLService;
import '../services/mongodb_service.dart' show MongoDBService;
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
          .map((json) => DbConnectionConfig.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    });
  }

  /// 处理节点选择
  void _handleNodeSelected(DbTreeNode node) {
    setState(() {
      switch (node.type) {
        case TreeNodeType.connection:
          // 连接节点选择逻辑由外部处理
          break;
        case TreeNodeType.database:
          _selectedDatabase = node.database;
          _selectedTable = null;
          break;
        case TreeNodeType.table:
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
          break;
        case TreeNodeType.folder:
        case TreeNodeType.field:
          break;
      }
    });
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
      });
    }
    setState(() {});
  }

  /// 连接数据库（真实）
  Future<void> _connectToDatabase(DbConnectionConfig config) async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    try {
      // 根据类型创建对应的服务实例
      DatabaseService service;
      switch (config.type) {
        case DbType.sqlite:
          service = SQLiteService(config);
          break;
        case DbType.mysql:
          service = MySQLService(config);
          break;
        case DbType.postgresql:
          service = PostgreSQLService(config);
          break;
        case DbType.mongodb:
          service = MongoDBService(config);
          break;
      }

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
              Text('数据库连接', style: HeroUiTypography.heading4),
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
                Text('DATABASE', style: HeroUiTypography.bodyXsMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在连接数据库...', style: HeroUiTypography.bodySm),
          ],
        ),
      );
    }

    if (_currentConnection == null) return _buildWelcomeScreen();
    if (_selectedTable == null) return _buildDatabaseOverview();
    return _buildTableDetail();
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
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text('数据库管理', style: HeroUiTypography.heading3),
          const SizedBox(height: 8),
          Text(
            '连接数据库以开始管理',
            style: HeroUiTypography.bodySm.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.5),
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
    if (_selectedDatabase == null) return const SizedBox.shrink();
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
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
      onTap: () {
        setState(() {
          _selectedTable = table;
          _showConnectionList = false;
        });
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.5),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  /// 表详情
  Widget _buildTableDetail() {
    if (_selectedTable == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (MediaQuery.of(context).size.width < 600)
                IconButton(
                  icon: const Icon(LucideIcons.arrowLeft),
                  onPressed: () => setState(() => _selectedTable = null),
                ),
              Text(_selectedTable!.name, style: HeroUiTypography.heading4),
              const SizedBox(width: 12),
              Text(
                '${_selectedTable!.rowCount} 条数据',
                style: HeroUiTypography.bodyXs.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('字段', style: HeroUiTypography.bodySmMedium),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _selectedTable!.fields.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildFieldItem(_selectedTable!.fields[index]),
            ),
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
          Expanded(child: Text(field.name, style: HeroUiTypography.bodyXsMedium)),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.4),
              ),
            ),
        ],
      ),
    );
  }

  /// 显示连接对话框
  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        onConnect: (config) {
          _connectToDatabase(config);
        },
      ),
    );
  }
}

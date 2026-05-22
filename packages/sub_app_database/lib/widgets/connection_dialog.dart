import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:sub_app_database/models/database_models.dart';
import 'package:sub_app_database/services/sqlite_service.dart'show SQLiteService;
import 'package:sub_app_database/services/postgresql_service.dart'show PostgreSQLService;
import 'package:sub_app_database/services/mysql_service.dart' show MySQLService;
import 'package:sub_app_database/services/mongodb_service.dart' show MongoDBService;

/// 新建连接对话框
class ConnectionDialog extends StatefulWidget {
  final void Function(DbConnectionConfig) onConnect;
  final void Function(DbConnectionConfig) onSave;

  const ConnectionDialog({
    super.key,
    required this.onConnect,
    required this.onSave,
  });

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _nameController = TextEditingController();
  DbType _selectedType = DbType.postgresql;
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '5432');
  final _usernameController = TextEditingController(text: 'postgres');
  final _passwordController = TextEditingController();
  final _databaseController = TextEditingController(text: 'postgres');
  final _filePathController = TextEditingController();

  bool _isTesting = false;
  bool? _testResult;
  String? _testMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _databaseController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  DbConnectionConfig _buildConfig() {
    return DbConnectionConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _selectedType,
      host: _selectedType != DbType.sqlite ? _hostController.text : null,
      port: _selectedType != DbType.sqlite && _portController.text.isNotEmpty
          ? int.tryParse(_portController.text)
          : null,
      username:
          _selectedType != DbType.sqlite ? _usernameController.text : null,
      password:
          _selectedType != DbType.sqlite ? _passwordController.text : null,
      databaseName:
          _selectedType != DbType.sqlite ? _databaseController.text : null,
      filePath:
          _selectedType == DbType.sqlite ? _filePathController.text : null,
      lastConnected: DateTime.now(),
    );
  }

  Future<void> _testConnection() async {
    // TODO: 添加表单验证
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testMessage = null;
    });

    try {
      final config = _buildConfig();
      bool success = false;
      String message = '';

      switch (config.type) {
        case DbType.sqlite:
          final service = SQLiteService(config);
          success = await service.testConnection();
          message = success ? 'SQLite 连接成功' : '无法打开数据库文件';
        case DbType.mysql:
          final service = MySQLService(config);
          success = await service.testConnection();
          message = success ? 'MySQL 连接成功' : '连接失败，请检查配置';
        case DbType.postgresql:
          final service = PostgreSQLService(config);
          success = await service.testConnection();
          message = success ? 'PostgreSQL 连接成功' : '连接失败，请检查配置';
        case DbType.mongodb:
          final service = MongoDBService(config);
          success = await service.testConnection();
          message = success ? 'MongoDB 连接成功' : '连接失败，请检查配置';
      }

      setState(() {
        _isTesting = false;
        _testResult = success;
        _testMessage = message;
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testResult = false;
        _testMessage = '测试失败: ${e.toString()}';
      });
    }
  }

  void _handleConnect() {
    // TODO: 添加表单验证
    final config = _buildConfig();
    context.pop();
    widget.onConnect(config);
  }

  void _handleSave() {
    // TODO: 添加表单验证
    final config = _buildConfig();
    context.pop();
    widget.onSave(config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建数据库连接'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 连接名称
              TextField(
                controller: _nameController,
                hintText: '输入连接名称',
              ),
              const SizedBox(height: 16),
              // TODO: 数据库类型选择 - 需要正确的 Select 组件用法
              Text('数据库类型: ${_selectedType.displayName}'),
              const SizedBox(height: 16),
              if (_selectedType == DbType.sqlite)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _filePathController,
                        hintText: '选择 SQLite 文件',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      variance: ButtonVariance.ghost,
                      icon: const Icon(Icons.folder_open),
                      onPressed: () {},
                    ),
                  ],
                ),
              if (_selectedType != DbType.sqlite) ...[
                TextField(
                  controller: _hostController,
                  hintText: 'localhost',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  hintText: '5432',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  hintText: 'postgres',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  hintText: '输入密码',
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _databaseController,
                  hintText: '输入数据库名',
                ),
              ],
              if (_testMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testResult == true
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult == true ? Icons.check_circle : Icons.error,
                        size: 18,
                        color: _testResult == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_testMessage!),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SecondaryButton(
          onPressed: () => context.pop(),
          child: const Text('取消'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecondaryButton(
              onPressed: _isTesting ? null : _testConnection,
              child: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('测试'),
            ),
            const SizedBox(width: 8),
            PrimaryButton(
              onPressed: _handleConnect,
              child: const Text('连接'),
            ),
            const SizedBox(width: 8),
            SecondaryButton(
              onPressed: _handleSave,
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
}

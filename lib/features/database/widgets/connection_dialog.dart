import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../models/database_models.dart';
import '../services/sqlite_service.dart' show SQLiteService;
import '../services/postgresql_service.dart' show PostgreSQLService;
import '../services/mysql_service.dart' show MySQLService;
import '../services/mongodb_service.dart' show MongoDBService;

/// 新建连接对话框
class ConnectionDialog extends StatefulWidget {
  final Function(DbConnectionConfig) onConnect;
  final Function(DbConnectionConfig) onSave;

  const ConnectionDialog({
    super.key,
    required this.onConnect,
    required this.onSave,
  });

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

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
          break;
        case DbType.mysql:
          final service = MySQLService(config);
          success = await service.testConnection();
          message = success ? 'MySQL 连接成功' : '连接失败，请检查配置';
          break;
        case DbType.postgresql:
          final service = PostgreSQLService(config);
          success = await service.testConnection();
          message = success ? 'PostgreSQL 连接成功' : '连接失败，请检查配置';
          break;
        case DbType.mongodb:
          final service = MongoDBService(config);
          success = await service.testConnection();
          message = success ? 'MongoDB 连接成功' : '连接失败，请检查配置';
          break;
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
    if (!_formKey.currentState!.validate()) return;
    final config = _buildConfig();
    Navigator.of(context).pop();
    widget.onConnect(config);
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;
    final config = _buildConfig();
    Navigator.of(context).pop();
    widget.onSave(config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建数据库连接'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '连接名称',
                    hintText: '输入连接名称',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return '请输入连接名称';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<DbType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: '数据库类型'),
                  items: DbType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value!;
                      _testResult = null;
                      _testMessage = null;
                      if (_selectedType == DbType.mysql) {
                        _portController.text = '3306';
                      } else if (_selectedType == DbType.postgresql) {
                        _portController.text = '5432';
                      } else if (_selectedType == DbType.mongodb) {
                        _portController.text = '27017';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_selectedType == DbType.sqlite)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _filePathController,
                          decoration: const InputDecoration(
                            labelText: '数据库文件',
                            hintText: '选择 SQLite 文件',
                          ),
                          validator: (value) {
                            if (_selectedType == DbType.sqlite &&
                                (value == null || value.isEmpty)) {
                              return '请选择数据库文件';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(LucideIcons.folderOpen),
                        onPressed: () {},
                        tooltip: '选择文件',
                      ),
                    ],
                  ),
                if (_selectedType != DbType.sqlite) ...[
                  TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '主机',
                      hintText: 'localhost',
                    ),
                    validator: (value) {
                      if (_selectedType != DbType.sqlite &&
                          (value == null || value.isEmpty)) {
                        return '请输入主机地址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '5432',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      hintText: 'postgres',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码',
                      hintText: '输入密码',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _databaseController,
                    decoration: const InputDecoration(
                      labelText: '数据库名',
                      hintText: '输入数据库名',
                    ),
                  ),
                ],
                if (_testMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testResult == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testResult == true
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult == true
                              ? LucideIcons.checkCircle
                              : LucideIcons.xCircle,
                          size: 18,
                          color: _testResult == true
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: TextStyle(
                              color: _testResult == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.wifi, size: 16),
              label: const Text('测试'),
            ),
            const SizedBox(width: 8),
            HeroUiButton(
              label: '连接',
              onPressed: _handleConnect,
              variant: HeroUiButtonVariant.primary,
              size: HeroUiButtonSize.sm,
            ),
            const SizedBox(width: 8),
            HeroUiButton(
              label: '保存',
              onPressed: _handleSave,
              variant: HeroUiButtonVariant.secondary,
              size: HeroUiButtonSize.sm,
            ),
          ],
        ),
      ],
    );
  }
}

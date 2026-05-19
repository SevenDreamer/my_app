import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/rust/ffi_auth.dart';

/// 应用管理界面（仅管理员）
class AppManagementScreen extends StatefulWidget {
  final String token;

  const AppManagementScreen({super.key, required this.token});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  List<SubApp> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });

    final result = AuthFFI.instance.getApps(widget.token);
    final data = jsonDecode(result);

    if (data['ok'] == true) {
      final appList = data['data'] as List<dynamic>;
      setState(() {
        _apps = appList
            .map((app) => SubApp.fromJson(app as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _apps = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：${data['error'] ?? '未知错误'}')),
        );
      }
    }
  }

  Future<void> _showAppDialog({SubApp? app}) async {
    final isEditing = app != null;
    final nameController = TextEditingController(text: app?.name ?? '');
    final descController = TextEditingController(text: app?.description ?? '');
    final iconController = TextEditingController(text: app?.iconName ?? '');
    final routeController = TextEditingController(text: app?.route ?? '');
    bool isActive = app?.isEnabled ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑应用' : '添加应用'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '应用名称 *',
                    hintText: '例如：聊天助手',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '应用描述',
                    hintText: '例如：AI 智能对话助手',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(
                    labelText: '图标名称 *',
                    hintText: '例如：message_circle',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: routeController,
                  decoration: const InputDecoration(
                    labelText: '路由路径 *',
                    hintText: '例如：/chat',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('启用'),
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() {
                      isActive = value ?? true;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 验证输入
                if (nameController.text.isEmpty ||
                    iconController.text.isEmpty ||
                    routeController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写必填字段')),
                  );
                  return;
                }

                // 生成 app_name（从 route 中提取）
                final appName = routeController.text.replaceAll('/', '');

                Map<String, dynamic> result;

                if (isEditing) {
                  // 更新应用
                  final updateResult = AuthFFI.instance.updateApp(
                    app.dbId,
                    jsonEncode({
                      'display_name': nameController.text,
                      'description': descController.text,
                      'icon': iconController.text,
                      'route': routeController.text,
                      'is_active': isActive,
                    }),
                    widget.token,
                  );
                  result = jsonDecode(updateResult) as Map<String, dynamic>;
                } else {
                  // 创建应用
                  final createResult = AuthFFI.instance.registerApp(
                    jsonEncode({
                      'app_name': appName,
                      'display_name': nameController.text,
                      'description': descController.text,
                      'icon': iconController.text,
                      'route': routeController.text,
                      'is_active': isActive,
                    }),
                    widget.token,
                  );
                  result = jsonDecode(createResult) as Map<String, dynamic>;
                }

                if (result['ok'] == true) {
                  Navigator.of(context).pop();
                  _loadApps(); // 刷新列表
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('操作失败：${result['error'] ?? '未知错误'}')),
                  );
                }
              },
              child: Text(isEditing ? '更新' : '创建'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteApp(SubApp app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除应用"${app.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = AuthFFI.instance.deleteApp(
        app.dbId,
        widget.token,
      );
      final data = jsonDecode(result);

      if (data['ok'] == true) {
        _loadApps(); // 刷新列表
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：${data['error'] ?? '未知错误'}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用管理'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAppDialog(),
            tooltip: '添加应用',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? const Center(child: Text('暂无应用，点击右上角 + 添加'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _apps.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final app = _apps[index];
                    return _AppManagementCard(
                      app: app,
                      onEdit: () => _showAppDialog(app: app),
                      onDelete: () => _deleteApp(app),
                    );
                  },
                ),
    );
  }
}

/// 应用管理列表项
class _AppManagementCard extends StatelessWidget {
  final SubApp app;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppManagementCard({
    required this.app,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return HeroUiCard(
      borderRadius: 12,
      showShadow: false,
      borderColor: Colors.transparent,
      body: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: app.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(app.icon, size: 22, color: app.color),
          ),
          const SizedBox(width: 16),

          // 应用信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  app.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: app.isEnabled
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              app.isEnabled ? '已启用' : '已禁用',
              style: TextStyle(
                fontSize: 12,
                color: app.isEnabled ? Colors.green : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 操作按钮
          IconButton(
            icon: const Icon(LucideIcons.edit2, size: 18),
            onPressed: onEdit,
            tooltip: '编辑',
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}

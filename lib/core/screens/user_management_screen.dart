import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/rust/ffi_auth.dart';
import 'dart:convert';

/// 用户管理界面（仅管理员）
class UserManagementScreen extends StatefulWidget {
  final String token;

  const UserManagementScreen({super.key, required this.token});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final result = AuthFFI.instance.getUsers(widget.token);
    final data = jsonDecode(result);

    if (data['ok'] == true) {
      setState(() {
        _users = data['data'] as List<dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _users = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户列表失败：${data['error']}')),
        );
      }
    }
  }

  Future<void> _createUser() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建用户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: '角色',
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('普通用户')),
                DropdownMenuItem(value: 'admin', child: Text('管理员')),
              ],
              onChanged: (value) {
                selectedRole = value ?? 'user';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (usernameController.text.trim().isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入用户名和密码')),
                );
                return;
              }
              Navigator.of(context).pop({
                'username': usernameController.text.trim(),
                'password': passwordController.text,
                'role': selectedRole,
              });
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null) {
      final requestJson = jsonEncode(result);
      final createResult = AuthFFI.instance.createUser(requestJson, widget.token);
      final createData = jsonDecode(createResult);

      if (createData['ok'] == true) {
        _loadUsers(); // 重新加载用户列表
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户创建成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建用户失败：${createData['error']}')),
          );
        }
      }
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final passwordController = TextEditingController();
    String selectedRole = user['role'] ?? 'user';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑用户 - ${user['username']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '新密码（留空表示不修改）',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: '角色',
              ),
              items: const [
                DropdownMenuItem(value: 'user', child: Text('普通用户')),
                DropdownMenuItem(value: 'admin', child: Text('管理员')),
              ],
              onChanged: (value) {
                selectedRole = value ?? 'user';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'password': passwordController.text.isEmpty
                    ? null
                    : passwordController.text,
                'role': selectedRole,
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      final requestJson = jsonEncode(result);
      final updateResult = AuthFFI.instance.updateUser(
        user['id'],
        requestJson,
        widget.token,
      );
      final updateData = jsonDecode(updateResult);

      if (updateData['ok'] == true) {
        _loadUsers(); // 重新加载用户列表
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户更新成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新用户失败：${updateData['error']}')),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 ${user['username']} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = AuthFFI.instance.deleteUser(user['id'], widget.token);
      final data = jsonDecode(result);

      if (data['ok'] == true) {
        _loadUsers(); // 重新加载用户列表
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('用户删除成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除用户失败：${data['error']}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createUser,
            tooltip: '创建用户',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('没有用户'))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: Icon(
                        user['role'] == 'admin'
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        color: user['role'] == 'admin'
                            ? Colors.red
                            : Colors.blue,
                      ),
                      title: Text(user['username'] ?? ''),
                      subtitle: Text('角色：${user['role']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editUser(user),
                            tooltip: '编辑',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteUser(user),
                            tooltip: '删除',
                            color: Colors.red,
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

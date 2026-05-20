import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
/// TODO: 待实现应用列表查询
class AppLauncherScreen extends StatefulWidget {
  final String? token;
  final String username;
  final String role;

  const AppLauncherScreen({
    super.key,
    this.token,
    this.username = '用户',
    this.role = 'user',
  });

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎，${widget.username}'),
        centerTitle: false,
        actions: [
          if (widget.role == 'admin')
            IconButton(
              icon: const Icon(LucideIcons.settings),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('管理功能开发中')),
                );
              },
              tooltip: '系统管理',
            ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
            tooltip: '登出',
          ),
        ],
      ),
      body: const Center(
        child: Text('暂无可用应用'),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
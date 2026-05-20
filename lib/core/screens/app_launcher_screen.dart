import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
/// TODO: 待实现 flutter_rust_bridge 认证 API 后完善
class AppLauncherScreen extends StatefulWidget {
  final String? token;

  const AppLauncherScreen({super.key, this.token});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    // TODO: 从 token 获取用户信息
    _username = '用户';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎，$_username'),
        centerTitle: false,
        actions: [
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
}

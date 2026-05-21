// 登录界面 - 使用 PostgreSQL 数据库认证
//
// 文件职责：仅负责状态和登录逻辑
// UI 组件已拆分到 lib/core/widgets/ 下独立文件

import 'package:flutter/material.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/core/screens/app_launcher_screen.dart';
import 'package:my_app/core/widgets/login_card.dart';

/// 登录页
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 调用 Rust 登录 API，失败时 throw 并附带友好消息
  Future<auth_api.UserInfo> _callLoginApi(String username, String password) async {
    try {
      return auth_api.login(username: username, password: password);
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (msg.contains('password') || msg.contains('密码') || msg.contains('invalid')) {
        throw Exception('用户名或密码错误');
      }
      if (msg.contains('user') || msg.contains('用户') || msg.contains('not found')) {
        throw Exception('用户不存在');
      }
      throw Exception(msg.isNotEmpty ? msg : '登录失败，请稍后重试');
    }
  }

  Future<void> _doLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请输入用户名和密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userInfo = await _callLoginApi(username, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'temp_token_${userInfo.userId}');

      if (!mounted) return;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => AppLauncherScreen(
            token: 'temp_token_${userInfo.userId}',
            username: userInfo.username,
            role: userInfo.role,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: LoginCard(
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            usernameController: _usernameController,
            passwordController: _passwordController,
            onLogin: _doLogin,
          ),
        ),
      ),
    );
  }
}

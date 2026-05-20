// 登录界面 - 使用 flutter_rust_bridge 自动生成的 API
// 样式：shadcn 风格（简洁、边框、适当间距）

import 'package:flutter/material.dart';
import 'package:my_app/core/auth_state.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 加载状态
  bool _isLoading = false;

  // 错误信息
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 执行登录
  Future<void> _doLogin() async {
    // 验证输入
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '请输入用户名和密码';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 调用 Rust `login()` 函数（通过 flutter_rust_bridge）
      final token = auth_api.login(
        baseUrl: AppConfig.baseUrl,
        username: username,
        password: password,
      );

      // 登录成功，验证 token 并获取用户信息
      final userInfo = auth_api.verifyToken(
        baseUrl: AppConfig.baseUrl,
        token: token,
      );

      // 存储到全局状态
      AuthState().login(token, userInfo, AppConfig.baseUrl);

      // 跳转到主界面
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '登录失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // shadcn 风格浅灰背景
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)), // shadcn 边框色
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/图标
                const Icon(
                  Icons.lock_person,
                  size: 48,
                  color: Color(0xFF2563EB), // shadcn blue
                ),
                const SizedBox(height: 24),

                // 标题
                const Text(
                  'My App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600, // shadcn 使用中等粗细
                    color: Color(0xFF0F172A), // shadcn slate-900
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 用户名输入框（shadcn 风格）
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: '用户名',
                    hintText: '请输入用户名',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                  enabled: !_isLoading,
                  onSubmitted: (_) => _doLogin(),
                ),
                const SizedBox(height: 16),

                // 密码输入框（shadcn 风格）
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                  onSubmitted: (_) => _doLogin(),
                ),
                const SizedBox(height: 24),

                // 登录按钮（shadcn 风格）
                ElevatedButton(
                  onPressed: _isLoading ? null : _doLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // shadcn blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                ),

                // 错误信息
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: Color(0xFFDC2626)), // shadcn red
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

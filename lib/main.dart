import 'package:shadcn_flutter/shadcn_flutter.dart' hide Scaffold;
import 'package:flutter/material.dart' show Scaffold;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/screens/app_launcher_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 flutter_rust_bridge
  await RustLib.init();

  // 初始化 PostgreSQL 数据库连接
  String? dbError;
  try {
    final result = auth_api.initAuthDb();
    print('DB init: $result');
  } catch (e) {
    dbError = e.toString();
    print('DB init failed: $e');
  }

  // 检查登录状态
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  runApp(MyApp(initialToken: token, dbError: dbError));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  final String? dbError;

  const MyApp({super.key, this.initialToken, this.dbError});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'My App',
      theme: const ThemeData.dark(),
      materialTheme: obsidianTheme(),
      home: _getHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _getHomeScreen() {
    if (dbError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('数据库连接失败', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(dbError!, style: const TextStyle(color: Color(0xFF9E9E9E))),
              ],
            ),
          ),
        ),
      );
    }
    if (initialToken != null) {
      try {
        final userInfo = auth_api.verifyToken(token: initialToken!);
        return AppLauncherScreen(
          token: initialToken,
          username: userInfo.username,
          role: userInfo.role,
        );
      } catch (_) {
        // token 无效，跳转登录页
      }
    }
    return const LoginScreen();
  }
}
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'rust/ffi_manual.dart';
import 'rust/ffi_auth.dart';
import 'rust/frb_generated.dart';
import 'core/theme/app_theme.dart';
import 'core/screens/login_screen.dart';
import 'core/screens/app_launcher_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 flutter_rust_bridge（必须在使用任何 Rust API 之前调用）
  await RustLib.init();

  // 初始化手动 FFI（用于其他功能）
  CoreFFI.init();
  AuthFFI.init();

  // 初始化认证数据库
  final authResult = AuthFFI.instance.initAuth();
  print('Auth DB init: $authResult');

  // 检查登录状态
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');

  runApp(MyApp(initialToken: token));
}

class MyApp extends StatelessWidget {
  final String? initialToken;

  const MyApp({super.key, this.initialToken});

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
    if (initialToken != null) {
      // 验证 token 是否有效
      final result = AuthFFI.instance.getCurrentUser(initialToken!);
      final data = jsonDecode(result);
      if (data['ok'] == true) {
        return AppLauncherScreen(token: initialToken);
      }
    }
    return const LoginScreen();
  }
}

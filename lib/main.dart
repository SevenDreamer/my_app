import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:my_app/core/config/app_config.dart';
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

  // 从本地持久化存储恢复登录态（不依赖 Rust 内存中的 CURRENT_USER）
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getInt('user_id');
  final username = prefs.getString('username');
  final role = prefs.getString('role');

  runApp(
    MyApp(
      initialToken: token,
      initialUserId: userId,
      initialUsername: username,
      initialRole: role,
      dbError: dbError,
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  final int? initialUserId;
  final String? initialUsername;
  final String? initialRole;
  final String? dbError;

  const MyApp({
    super.key,
    this.initialToken,
    this.initialUserId,
    this.initialUsername,
    this.initialRole,
    this.dbError,
  });

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc(),
        radius: 0.7,
      ),
      home: _getHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _getHomeScreen() {
    if (dbError != null) {
      return Scaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text('数据库连接失败').large().bold(),
                const SizedBox(height: 8),
                Text(dbError!).muted(),
              ],
            ),
          ),
        ),
      );
    }
    // 本地持久化数据完整 → 直接恢复登录态，无需调用 Rust verify_token
    if (initialToken != null &&
        initialUserId != null &&
        initialUsername != null &&
        initialRole != null) {
      return AppLauncherScreen(
        token: initialToken,
        username: initialUsername!,
        role: initialRole!,
      );
    }
    return const LoginScreen();
  }
}

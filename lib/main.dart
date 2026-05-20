import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rust/frb_generated.dart';
import 'core/theme/app_theme.dart';
import 'core/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 flutter_rust_bridge（必须在使用任何 Rust API 之前调用）
  await RustLib.init();

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
      // TODO: 使用 flutter_rust_bridge 验证 token
      // 目前直接跳转到登录页
    }
    return const LoginScreen();
  }
}

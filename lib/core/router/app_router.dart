import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/screens/app_launcher_screen.dart';
import 'package:my_app/features/image/image_app.dart';
import 'package:my_app/features/chat/chat_app.dart';
import 'package:my_app/features/bar/bar_app.dart';
import 'package:my_app/features/bar/screens/add_record_page.dart';
import 'package:my_app/features/database/database_app.dart' show DatabaseManagerApp;

/// 路由路径常量
class AppRoutes {
  static const login = '/login';
  static const launcher = '/launcher';
  static const image = '/app/image';
  static const hermes = '/app/hermes';
  static const bar = '/app/bar';
  static const database = '/app/database';
}

/// 创建 GoRouter 实例
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.launcher,
    redirect: _guard,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.launcher,
        name: 'launcher',
        builder: (context, state) => const AppLauncherScreen(),
        routes: [
          GoRoute(
            path: 'app/image',
            name: 'image',
            builder: (context, state) => const ImageApp(),
          ),
          GoRoute(
            path: 'app/hermes',
            name: 'hermes',
            builder: (context, state) => const ChatApp(),
          ),
          GoRoute(
            path: 'app/bar',
            name: 'bar',
            builder: (context, state) => const BarApp(),
            routes: [
              GoRoute(
                path: 'add-record',
                name: 'add-record',
                builder: (context, state) => const AddRecordPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'app/database',
            name: 'database',
            builder: (context, state) => const DatabaseManagerApp(),
          ),
        ],
      ),
    ],
  );
}

/// 路由守卫：检查登录态
Future<String?> _guard(context, GoRouterState state) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getInt('user_id');
  final username = prefs.getString('username');
  final role = prefs.getString('role');

  final isLoggedIn = token != null &&
      userId != null &&
      username != null &&
      role != null;

  final isGoingToLogin = state.matchedLocation == AppRoutes.login;

  // 未登录 → 跳转登录页
  if (!isLoggedIn && !isGoingToLogin) {
    return AppRoutes.login;
  }

  // 已登录 → 禁止访问登录页
  if (isLoggedIn && isGoingToLogin) {
    return AppRoutes.launcher;
  }

  return null;
}

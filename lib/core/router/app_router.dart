import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/screens/app_launcher_screen.dart';
import 'package:my_app/core/screens/settings_screen.dart';

// 导入子应用（从 SubAppRegistry 动态加载）
import 'package:sub_app_shared/sub_app_shared.dart';

// 路由路径常量
class AppRoutes {
  static const login = '/login';
  static const launcher = '/launcher';
  static const settings = '/settings';
  // 子应用路由动态生成，不需要硬编码
}

/// 创建 GoRouter 实例（动态从 SubAppRegistry 生成路由）
GoRouter createRouter() {
  // 基础路由
  final routes = <RouteBase>[
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.launcher,
      name: 'launcher',
      builder: (context, state) => const AppLauncherScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ];

  // 动态添加子应用路由（只注册已启用的）
  for (final app in SubAppRegistry.enabled) {
    routes.add(
      GoRoute(
        path: app.route,
        name: app.id,
        builder: (context, state) => app.builder(context),
        routes: app.routes ?? [],
      ),
    );
  }

  return GoRouter(
    initialLocation: AppRoutes.launcher,
    redirect: _guard,
    routes: routes,
  );
}

/// 路由守卫：检查登录态
Future<String?> _guard(context, GoRouterState state) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final userId = prefs.getInt('user_id');
  final username = prefs.getString('username');
  final role = prefs.getString('role');

  final isLoggedIn =
      token != null && userId != null && username != null && role != null;

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

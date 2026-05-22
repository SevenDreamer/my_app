import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/rust/hermes/frb_generated.dart' as hermes_rust;
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/theme/app_theme_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 flutter_rust_bridge (主模块)
  await RustLib.init();

  // 初始化 Hermes FRB 模块
  await hermes_rust.RustLib.init();

  // 初始化 PostgreSQL 数据库连接
  try {
    final result = auth_api.initAuthDb();
    print('DB init: $result');
  } catch (e) {
    print('DB init failed: $e');
  }

  runApp(
    const AppThemeScope(
      child: MyApp(),
    ),
  );
}

/// 全局 router 实例，供外部访问（如退出登录时调用 context.go()）
final appRouter = createRouter();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeScope = AppThemeScope.of(context);
    return ListenableBuilder(
      listenable: themeScope.notifier,
      builder: (context, _) {
        return ShadcnApp.router(
          title: AppConfig.appName,
          theme: themeScope.buildTheme(),
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

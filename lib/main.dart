import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 flutter_rust_bridge
  await RustLib.init();

  // 初始化 PostgreSQL 数据库连接
  try {
    final result = auth_api.initAuthDb();
    print('DB init: $result');
  } catch (e) {
    print('DB init failed: $e');
    // 数据库错误会在路由守卫中处理，或通过其他方式提示用户
  }

  runApp(const MyApp());
}

/// 全局 router 实例，供外部访问（如退出登录时调用 context.go()）
final appRouter = createRouter();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp.router(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.lightZinc(),
        radius: 0.7,
      ),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

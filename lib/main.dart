import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/rust/api/auth.dart' as auth_api;
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/config/feature_registry.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/theme/app_theme_scope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化主模块（始终需要）
  await RustLib.init();

  // 2. 尝试初始化可选功能模块（失败则静默禁用）
  await _initOptionalFeatures();

  // 3. 初始化 PostgreSQL 数据库连接
  try {
    final result = auth_api.initAuthDb();
    print('DB init: $result');
  } catch (e) {
    print('DB init failed: $e');
  }

  runApp(
    AppThemeScope(
      child: MyApp(
        hermesAvailable: FeatureRegistry.isAppAvailable('hermes'),
      ),
    ),
  );
}

/// 初始化可选功能模块
Future<void> _initOptionalFeatures() async {
  // Hermes：尝试加载 hermes_api Rust 动态库
  // 如果 hermes 功能包已安装，它会自动注册
  // 此处只需设置默认值，实际初始化由功能包完成
  FeatureRegistry.setAvailable('hermes', false); // 默认禁用

  // 如果 hermes 功能包已安装，它会在 main() 中调用：
  // FeatureRegistry.setAvailable('hermes', true);
  // FeatureRegistry.registerApp('hermes', (ctx) => const HermesApp());
}

/// 注意：Hermes 功能的完整初始化需要：
/// 1. Rust 侧编译 hermes_api crate（生成 hermes_api.dll）
/// 2. Dart 侧导入 hermes 功能包并调用 RustLib.init()
/// 3. 如果以上任一步骤失败，Hermes 入口会自动隐藏

/// 全局 router 实例，供外部访问（如退出登录时调用 context.go()）
final appRouter = createRouter();

class MyApp extends StatelessWidget {
  /// Hermes 功能是否可用
  final bool hermesAvailable;

  const MyApp({super.key, this.hermesAvailable = false});

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

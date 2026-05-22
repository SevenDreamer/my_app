import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/rust/frb_generated.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/theme/app_theme_scope.dart';

// 导入子应用（按需取消注释即可启用）
import 'package:sub_app_database/sub_app_database.dart';
import 'package:sub_app_image/sub_app_image.dart';
// import 'package:sub_app_auth/sub_app_auth.dart';
// import 'package:sub_app_chat/sub_app_chat.dart';
// import 'package:sub_app_code/sub_app_code.dart';

// SubAppRegistry 会在 main() 中注册子应用
import 'package:sub_app_shared/sub_app_shared.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Rust 核心
  await RustLib.init();

  // 2. 注册子应用
  SubAppRegistry.register(DatabaseSubApp());
  SubAppRegistry.register(ImageSubApp());

  // 3. 从 SharedPreferences 加载子应用开关状态
  final prefs = await SharedPreferences.getInstance();
  for (final app in SubAppRegistry.all) {
    final enabled = prefs.getBool('app_enabled_${app.id}') ?? true;
    if (enabled) {
      SubAppRegistry.enable(app.id);
    } else {
      SubAppRegistry.disable(app.id);
    }
  }

  print('Registered ${SubAppRegistry.all.length} sub-apps: '
      '${SubAppRegistry.all.map((a) => a.id).join(', ')}');
  print('Enabled ${SubAppRegistry.enabled.length} sub-apps: '
      '${SubAppRegistry.enabled.map((a) => a.id).join(', ')}');

  runApp(const MyApp());
}

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
          routeInformationParser: appRouter.routeInformationParser,
          routerDelegate: appRouter.routerDelegate,
          title: AppConfig.appName,
          theme: themeScope.buildTheme(),
          darkTheme: themeScope.buildDarkTheme(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

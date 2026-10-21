//! 应用入口：shadcn 主题外壳（ShadApp）+ Material 共存模式
//!
//! 采用 shadcn_ui 官方 interop 模式：ShadApp.custom 提供 shadcn 主题，
//! appBuilder 内的 MaterialApp 继承它生成的 Material 主题再叠加
//! 公共层覆盖——Material 组件（NavigationBar/FAB 等）与 shadcn 组件同源。
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'design/theme.dart';
import 'app/home_page.dart';
import 'app/update/ci_notifier.dart';

Future<void> main() async {
  // 流水线通知服务（开关默认开——「我」页可关）
  // ignore: unawaited_futures
  CiNotifier.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      // 调试角标由内部的 MaterialApp 关闭（ShadApp.custom 无此参数）
      themeMode: ThemeMode.light,
      theme: AppTheme.shadLight,
      appBuilder: (context) {
        return MaterialApp(
          title: 'my_app',
          debugShowCheckedModeBanner: false,
          // ShadApp 自动生成的 Material 主题（色系与 shadcn 联动），
          // 再叠加我们自己的公共组件覆盖
          theme: AppTheme.materialize(Theme.of(context)),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const HomePage(),
          builder: (context, child) => ShadAppBuilder(child: child!),
        );
      },
    );
  }
}

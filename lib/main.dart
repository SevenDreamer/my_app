//! 应用入口：ShadApp 主题壳（业务层零 Material）
//!
//! ShadApp 标准构造内置 Material 联动（shadcn_ui 内部持有），业务代码
//! 只接触 shadcn_ui 与 design 层——Material 库在业务层全仓退场。
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'design/theme.dart';
import 'app/home_page.dart';
import 'app/update/boot_gate.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // FTheme（Forui 主题）——去 Material 化目标库；shadcn 期间双包共存
    return FTheme(
      data: FTheme.neutral.light.touch,
      child: ShadApp(
        title: 'my_app',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.shadLight,
        localizationsDelegates: const [
          GlobalShadLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const BootGate(child: HomePage()),
      ),
    );
  }
}

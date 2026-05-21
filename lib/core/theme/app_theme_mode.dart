import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// 应用主题模式枚举
enum AppThemeMode {
  light('浅色模式'),
  dark('深色模式'),
  system('跟随系统');

  final String displayName;

  const AppThemeMode(this.displayName);
}

/// 根据主题模式生成 shadcn ThemeData
///
/// [mode] 应用主题模式
/// [platformBrightness] 平台亮度，用于系统模式下确定实际主题
shadcn.ThemeData buildAppTheme(
  AppThemeMode mode, {
  Brightness platformBrightness = Brightness.light,
}) {
  final actualMode = mode == AppThemeMode.system
      ? (platformBrightness == Brightness.dark ? AppThemeMode.dark : AppThemeMode.light)
      : mode;

  final colorScheme = actualMode == AppThemeMode.dark
      ? shadcn.LegacyColorSchemes.darkZinc()
      : shadcn.LegacyColorSchemes.lightZinc();

  return shadcn.ThemeData(
    colorScheme: colorScheme,
    radius: 0.7,
  );
}

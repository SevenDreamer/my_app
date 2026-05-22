import 'package:shadcn_flutter/shadcn_flutter.dart';

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
ThemeData buildAppTheme(
  AppThemeMode mode, {
  Brightness platformBrightness = Brightness.light,
}) {
  final isDark = mode == AppThemeMode.dark ||
      (mode == AppThemeMode.system && platformBrightness == Brightness.dark);

  final colorScheme =
      isDark ? LegacyColorSchemes.darkZinc() : LegacyColorSchemes.lightZinc();

  return ThemeData(
    colorScheme: colorScheme,
    radius: 0.7,
  );
}

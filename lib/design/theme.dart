//! 全局主题：把设计 tokens 灌进 Flutter ThemeData 的唯一入口
//!
//! 主题 = 公共层（标题栏/按钮/卡片/列表/输入框）的基调来源；
//! 个性页面（如机器人眼睛）可在自己画布内自由表达，但公共组件遵循本主题。
import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// 简洁现代 · 亮色主题（当前唯一主题）
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.neutral,
      textTheme: base.textTheme.copyWith(
        titleLarge: AppTypography.h1,
        bodyMedium: AppTypography.bodyMd,
        labelSmall: AppTypography.labelSm,
      ),
      // 顶部标题栏：中性底、无阴影、无表面着色
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.neutral,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      // 卡片：白卡浮在灰底上（纯色差分层），不用阴影（DESIGN.md · Elevation）
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      // 列表行：图标与文字用主文字色
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.onSurface,
        textColor: AppColors.onSurface,
      ),
      // 输入框：neutral 填充 + md 圆角，聚焦描边 primary（DESIGN.md · Components）
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      // 主按钮：一屏至多一个（DESIGN.md · Components）
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      // 分隔线：从主文字色派生的极淡线（不引入新颜色）
      dividerTheme: DividerThemeData(
        color: AppColors.onSurface.withValues(alpha: 0.08),
        thickness: 1,
      ),
      // 浮动按钮跟随强调色
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      // 底部导航：表面白底，选中用强调色 + 淡染指示器
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const IconThemeData(color: AppColors.primary)
              : const IconThemeData(color: AppColors.secondary),
        ),
        labelTextStyle: const WidgetStatePropertyAll(AppTypography.labelSm),
      ),
    );
  }
}

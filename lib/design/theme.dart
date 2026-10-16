//! 主题：shadcn 主题为视觉唯一来源，Material 组件经映射层继承它
//!
//! 结构（参考 shadcn_ui 的 Material & Cuperertino interop 指南）：
//!   ShadThemeData（shadcn 色系 + DESIGN.md tokens 覆盖）
//!     → ShadApp 自动生成 Material ThemeData（色系联动）
//!       → AppTheme.materialize 叠加公共层覆盖（AppBar/导航/字阶）
//!   Material 组件与 shadcn 组件自此同源，不再有两套配色。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// shadcn 亮色主题：zinc 中性系打底 + DESIGN.md 的强调色/文字色覆盖
  static ShadThemeData get shadLight => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(
          primary: AppColors.primary, // Tool Blue：交互强调色
          foreground: AppColors.onSurface, // 主文字
          background: AppColors.neutral, // 页面底色
          secondary: AppColors.secondary, // 次要文字/非激活
          destructive: AppColors.error, // 错误与危险
        ),
      );

  /// 在 shadcn 生成的 Material 基础主题之上，叠加公共层组件覆盖。
  ///
  /// base 来自 `Theme.of(context)`（ShadApp 已把 shadcn 色系映射过去），
  /// 这里只补 shadcn 映射不到的部分：AppBar、底部导航、字阶、FAB。
  static ThemeData materialize(ThemeData base) {
    return base.copyWith(
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
      // 浮动按钮跟随强调色
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      // 分隔线：从主文字色派生的极淡线（不引入新颜色）
      dividerTheme: DividerThemeData(
        color: AppColors.onSurface.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}

//! 主题：shadcn 组件直接用 zinc 默认值，Material 组件经映射层与其同源
//!
//! 结构（参考 shadcn_ui 的 Material & Cuperertino interop 指南）：
//!   ShadThemeData（ShadZincColorScheme 完全默认，零覆盖）
//!     → ShadApp 自动生成 Material ThemeData（色系联动）
//!       → AppTheme.materialize 叠加公共层覆盖（AppBar/导航/字阶）
//!   Material 组件与 shadcn 组件自此同源，不再有两套配色。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// shadcn 亮色主题：**完全采用 zinc 默认值（零覆盖）**。
  ///
  /// shadcn 组件以包内调色板为唯一真源；Material 侧由 [materialize]
  /// 从 tokens 供值（tokens 的值与 zinc 同一调色板）。
  static ShadThemeData get shadLight => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
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

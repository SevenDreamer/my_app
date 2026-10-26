//! 主题：shadcn 组件直接用 zinc 默认值（零 Material）
//!
//! 去 Material 化后主题收束到一套：ShadThemeData（zinc 默认值）。
//! 业务页面的字阶/颜色直接引 tokens（AppTypography / AppColors），
//! 不再有 Material 主题映射层（materialize 已随去 Material 退场）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  AppTheme._();

  /// shadcn 亮色主题：**完全采用 zinc 默认值（零覆盖）**。
  static ShadThemeData get shadLight => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      );
}

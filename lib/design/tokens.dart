//! 设计 tokens：DESIGN.md 的代码映射（值必须与 DESIGN.md 严格一致）
//!
//! 页面与组件不允许硬编码颜色/字号/圆角/间距，一律从本文件取。
//! 修改视觉基调时：先改 DESIGN.md，再同步这里。
import 'package:flutter/material.dart';

/// 色彩（DESIGN.md · Colors，与 shadcn zinc 默认值逐一对齐）
///
/// shadcn_ui 组件直接用 ShadZincColorScheme 默认值（零覆盖），
/// 本类只为 Material 侧与自建壳供值——两侧同属一个调色板。
abstract class AppColors {
  /// 唯一强调色：shadcn zinc-900 近黑（黑即强调，不使用彩色强调）
  static const Color primary = Color(0xFF18181B);

  /// 强调色之上的文字：shadcn primaryForeground
  static const Color onPrimary = Color(0xFFFAFAFA);

  /// 次要文字与非激活图标：shadcn mutedForeground
  static const Color secondary = Color(0xFF71717A);

  /// 页面底色：shadcn background（纯白，分层靠 1px 描边）
  static const Color neutral = Color(0xFFFFFFFF);

  /// 卡片/输入区/弹层表面
  static const Color surface = Color(0xFFFFFFFF);

  /// 主文字与主要图标：shadcn zinc-950 近黑
  static const Color onSurface = Color(0xFF09090B);

  /// 错误与危险操作（文字/图标档 red-600，白底过 AA；
  /// 危险按钮底色由 shadcn destructive 提供）
  static const Color error = Color(0xFFDC2626);

  /// 1px 描边（shadcn border）：卡片与容器分层用
  static const Color border = Color(0xFFE4E4E7);
}

/// 间距（DESIGN.md · Layout，8pt 网格）
abstract class AppSpacing {
  /// 元素内间隙
  static const double xs = 4;
  static const double sm = 8;

  /// 组件间距 / 页面左右留白
  static const double md = 16;

  /// 区块间距
  static const double lg = 24;
}

/// 圆角（DESIGN.md · Shapes）
abstract class AppRadius {
  /// 小型内嵌元素（标签、徽标）
  static const double sm = 6;

  /// 按钮、输入框
  static const double md = 10;

  /// 卡片、弹层
  static const double lg = 16;
}

/// 字阶（DESIGN.md · Typography，系统默认字体，不引入自定义字体）
///
/// 每档都显式携带颜色：避免 copyWith 后 color 丢失导致
/// 文字颜色跟随错误的 fallback 链（出现白底白字）。
abstract class AppTypography {
  /// h1：页面标题（1.75rem/700），每页至多一个
  static const TextStyle h1 = TextStyle(
    color: AppColors.onSurface,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// body-md：正文与列表主文本（1rem/400）
  static const TextStyle bodyMd = TextStyle(
    color: AppColors.onSurface,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// label-sm：辅助文字/标签/状态提示（0.8125rem/500，次要信息专用）
  static const TextStyle labelSm = TextStyle(
    color: AppColors.secondary,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
}

//! 设计 tokens：DESIGN.md 的代码映射（值必须与 DESIGN.md 严格一致）
//!
//! 页面与组件不允许硬编码颜色/字号/圆角/间距，一律从本文件取。
//! 修改视觉基调时：先改 DESIGN.md，再同步这里。
import 'package:flutter/material.dart';

/// 色彩（DESIGN.md · Colors）
abstract class AppColors {
  /// Tool Blue：唯一强调色，仅用于交互（主按钮/选中/链接/焦点）
  static const Color primary = Color(0xFF1D4ED8);

  /// 强调色之上的文字（白）
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// 次要文字与非激活图标
  static const Color secondary = Color(0xFF64748B);

  /// 页面底色（近白浅灰，让白色卡片浮出来）
  static const Color neutral = Color(0xFFF8FAFC);

  /// 卡片/输入区/弹层表面
  static const Color surface = Color(0xFFFFFFFF);

  /// 主文字与主要图标（近黑不纯黑）
  static const Color onSurface = Color(0xFF0F172A);

  /// 错误与危险操作，绝不装饰性使用
  static const Color error = Color(0xFFDC2626);
}

/// 间距（DESIGN.md · Layout，8pt 网格）
abstract class AppSpacing {
  /// 元素内间隙
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
abstract class AppTypography {
  /// h1：页面标题（1.75rem/700），每页至多一个
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// body-md：正文与列表主文本（1rem/400）
  static const TextStyle bodyMd = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// label-sm：辅助文字/标签/状态提示（0.8125rem/500）
  static const TextStyle labelSm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
}

//! AppButton（DESIGN.md · 变体矩阵）：交互按钮的统一词汇。
//!
//! 组合不发明：底层是 shadcn 的 ShadButton（组件层唯一依赖），本件只做
//! 「设计语言词汇 → shadcn 实现」的映射，页面一律用本件不直用 ShadButton。
//! 矩阵：variant（primary/outline/ghost/danger）× size（sm/md）+ 三态
//! （hover 4%/pressed 8%/disabled 40% 由 shadcn 提供）。一屏 primary ≤ 1。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens.dart';

/// 按钮变体（DESIGN.md · 变体矩阵）
enum AppButtonVariant {
  /// 黑底白字——一屏唯一的高强调动作
  primary,

  /// 描边——次操作
  outline,

  /// 无底——弱操作/尾随
  ghost,

  /// 红字——危险操作（重置/删除）
  danger,
}

/// 按钮尺寸：sm 28h / md 36h
enum AppButtonSize { sm, md }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.onPressed,
    this.icon,
  });

  final String label;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final shadSize =
        size == AppButtonSize.sm ? ShadButtonSize.sm : ShadButtonSize.regular;
    final text = Text(label);
    final child = icon == null
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: size == AppButtonSize.sm ? 14 : 16),
            const SizedBox(width: AppSpacing.xs),
            text,
          ]);
    return switch (variant) {
      AppButtonVariant.primary =>
        ShadButton(size: shadSize, onPressed: onPressed, child: child),
      AppButtonVariant.outline =>
        ShadButton.outline(size: shadSize, onPressed: onPressed, child: child),
      AppButtonVariant.ghost =>
        ShadButton.ghost(size: shadSize, onPressed: onPressed, child: child),
      AppButtonVariant.danger => ShadButton.ghost(
          size: shadSize,
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(color: AppColors.error)),
        ),
    };
  }
}

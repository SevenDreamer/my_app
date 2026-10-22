//! 页面头（纯 widgets 实现——去 Material 化）
//!
//! shadcn_ui 无 AppBar，本组件是纯布局壳：SafeArea + Row（返回/标题/actions）。
//! 不依赖 Material——任何上下文（含 shadcn 弹层）可用。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart'; // LucideIcons

import '../tokens.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.showBack,
  });

  /// 标题
  final String title;

  /// 自定义标题内容（优先于 title 文本，如带版本号的标题行）
  final Widget? titleWidget;

  /// 右侧动作区
  final List<Widget>? actions;

  /// 背景色（默认跟随主题中性底）
  final Color? backgroundColor;

  /// 前景色：标题与图标（默认主文字色）
  final Color? foregroundColor;

  /// 强制显示/隐藏返回箭头（不传=自动判断可返回才显示）
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();
    final fg = foregroundColor ?? AppColors.onSurface;
    return Material(
      color: backgroundColor ?? AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  icon: Icon(LucideIcons.chevronLeft, color: fg),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: AppSpacing.md),
              Expanded(
                child: titleWidget ??
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              ...?actions,
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

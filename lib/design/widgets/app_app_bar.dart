//! 组件库：统一标题栏（DESIGN.md · Layout · 导航的实现）
//!
//! 封装 AppBar 的重复配置：自动返回按钮（在可返回的子页面显示，
//! tab 根页面不显示）、统一标题字重与配色；支持自定义背景
//! （如机器人眼睛的黑底个性页面）。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
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

  /// 是否显示返回按钮；null = 按"当前能否返回上一页"自动判断
  final bool? showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final bool back = showBack ?? Navigator.canPop(context);
    final Color? fg = foregroundColor;

    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      foregroundColor: fg,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              tooltip: '返回',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: titleWidget ??
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: fg ?? AppColors.onSurface,
                ),
          ),
      titleSpacing: back ? AppSpacing.sm : AppSpacing.md,
      actions: actions,
    );
  }
}

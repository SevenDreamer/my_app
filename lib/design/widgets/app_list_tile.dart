//! 设置/列表行（纯 widgets 实现——去 Material 化）
//!
//! 悬停/按压反馈由 MouseRegion + AnimatedContainer 自绘（不依赖 Material
//! 的 InkWell——shadcn 弹层等无 Material 祖先的上下文也能用）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.icon,
    this.iconLabel,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final IconData? icon;

  /// 字母图标方块（与 icon 二选一——模型/角色行用首字母）
  final String? iconLabel;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (icon != null || iconLabel != null) ...[
                  // 图标底色块：primary 淡染 + primary 图标/字母
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    ),
                    child: icon != null
                        ? Icon(
                            icon,
                            size: 20,
                            color: AppColors.primary,
                          )
                        : Text(
                            iconLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing ??
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: AppColors.secondary,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider) const ShadSeparator.horizontal(),
      ],
    );
  }
}

/// 自绘悬停/按压行（去 Material：MouseRegion + AnimatedContainer）
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovering
                ? AppColors.onSurface.withValues(alpha: 0.04)
                : const Color(0x00000000),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

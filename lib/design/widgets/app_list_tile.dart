//! 组件库：列表行（DESIGN.md · Components · list-tile 的实现）
//!
//! 比原生 ListTile 精致：带底色的图标块、加粗标题 + 次要色副标题、
//! 悬停/按压反馈、可选底部分隔线。颜色只从 tokens 取。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  /// 左侧图标（会放进 primary 10% 淡底色块）
  final IconData? icon;

  /// 主标题
  final String title;

  /// 副标题（次要色小字）
  final String? subtitle;

  /// 右侧内容，默认是 chevron 箭头
  final Widget? trailing;

  /// 点击回调；null = 不可点击（无按压反馈）
  final VoidCallback? onTap;

  /// 是否显示底部分隔线
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          // 悬停/按压反馈：从主文字色派生的透明度变化（不引入新颜色）
          hoverColor: AppColors.onSurface.withValues(alpha: 0.04),
          highlightColor: AppColors.onSurface.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  // 图标底色块：primary 淡染 + primary 图标
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: AppColors.primary,
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.labelSmall,
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
        if (showDivider) const Divider(height: 1, indent: AppSpacing.md),
      ],
    );
  }
}

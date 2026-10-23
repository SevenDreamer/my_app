//! 设置行（紧凑单行：小图标 + 标题 + 右侧灰字/控件；去 Material）
//!
//! 设置类页面通用（「我」「关于」等）：40px 紧凑行，行间 ShadSeparator。
//! 悬停/按压反馈自绘（MouseRegion + AnimatedContainer），不依赖 Material。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../tokens.dart';

class AppSettingRow extends StatefulWidget {
  const AppSettingRow({
    super.key,
    this.icon,
    required this.title,
    this.detail,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  /// 行首小图标（18px 弱化色）
  final IconData? icon;
  final String title;

  /// 右侧灰字状态（如「已授权」「开发版」），按内容宽度排、贴右
  final String? detail;

  /// 右侧控件（优先于默认箭头）
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  State<AppSettingRow> createState() => _AppSettingRowState();
}

class _AppSettingRowState extends State<AppSettingRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: AppColors.secondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.detail != null) ...[
            Text(
              widget.detail!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          widget.trailing ??
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.secondary.withValues(alpha: 0.6),
              ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
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
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: row,
            ),
          ),
        ),
        if (widget.showDivider)
          const ShadSeparator.horizontal(
            margin: EdgeInsets.zero,
            thickness: 1,
            color: AppColors.border,
          ),
      ],
    );
  }
}

//! AppChip（DESIGN.md · 变体矩阵）：状态徽章/标签。
//!
//! 胶囊（radius 9999px）+ 6px 圆点；不引入新色相（status-badge 规格）。
//! 矩阵：variant（solid-tint 淡底 / outline 描边 / dot 纯圆点）× size（sm/md）。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

enum AppChipVariant {
  /// 淡底胶囊（icon-block 同源：primary 10% 淡底）
  solidTint,

  /// 描边胶囊
  outline,

  /// 仅圆点 + 文字（无底）
  dot,
}

enum AppChipSize { sm, md }

/// 语义色调（DESIGN.md · status-badge：normal=primary / busy=secondary / error=red）
enum AppChipTone { normal, busy, error }

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.solidTint,
    this.size = AppChipSize.sm,
    this.tone = AppChipTone.normal,
    this.showDot = true,
  });

  final String label;
  final AppChipVariant variant;
  final AppChipSize size;
  final AppChipTone tone;
  final bool showDot;

  (Color fg, Color bg) get _colors => switch (tone) {
        AppChipTone.normal => (
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.10)
          ),
        AppChipTone.busy => (
            AppColors.secondary,
            AppColors.secondary.withValues(alpha: 0.10)
          ),
        AppChipTone.error => (
            AppColors.error,
            AppColors.error.withValues(alpha: 0.12)
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    final isSm = size == AppChipSize.sm;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSm ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: switch (variant) {
          AppChipVariant.solidTint => bg,
          AppChipVariant.outline => null,
          AppChipVariant.dot => null,
        },
        borderRadius: BorderRadius.circular(AppRadius.lg), // 胶囊（9999 语义）
        border: variant == AppChipVariant.outline
            ? Border.all(color: fg.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: (isSm ? AppTypography.labelSm : AppTypography.bodyMd)
                .copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

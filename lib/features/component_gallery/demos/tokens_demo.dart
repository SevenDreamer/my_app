//! 设计 Tokens 样张：颜色 / 间距 / 圆角 / 字号
import 'package:flutter/widgets.dart';

import '../../../design/tokens.dart';

class TokensDemo extends StatelessWidget {
  const TokensDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const swatches = <(String, Color)>[
      ('primary', AppColors.primary),
      ('onPrimary', AppColors.onPrimary),
      ('secondary', AppColors.secondary),
      ('neutral', AppColors.neutral),
      ('surface', AppColors.surface),
      ('onSurface', AppColors.onSurface),
      ('error', AppColors.error),
      ('border', AppColors.border),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 色板
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (name, color) in swatches)
                Column(
                  children: [
                    Container(
                      width: 44,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(name, style: AppTypography.labelSm),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 间距
          const Text('间距 xs/sm/md/lg', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            for (final s in [
              ('xs', AppSpacing.xs),
              ('sm', AppSpacing.sm),
              ('md', AppSpacing.md),
              ('lg', AppSpacing.lg),
            ]) ...[
              Column(children: [
                Container(
                    width: s.$2 * 2, height: 12, color: AppColors.primary),
                Text(s.$1, style: AppTypography.labelSm),
              ]),
              const SizedBox(width: AppSpacing.sm),
            ],
          ]),
          const SizedBox(height: AppSpacing.md),
          // 圆角
          const Text('圆角 sm/md/lg', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            for (final r in [
              ('sm', AppRadius.sm),
              ('md', AppRadius.md),
              ('lg', AppRadius.lg),
            ]) ...[
              Container(
                width: 44,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(r.$2),
                ),
                alignment: Alignment.center,
                child: Text(r.$1, style: AppTypography.labelSm),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ]),
          const SizedBox(height: AppSpacing.md),
          // 字号
          const Text('h1', style: AppTypography.h1),
          const Text('bodyMd 正文', style: AppTypography.bodyMd),
          const Text('labelSm 辅助说明', style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

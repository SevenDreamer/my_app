//! 变体矩阵活文档（DESIGN.md · 组件变体矩阵的可视化真源）。
//!
//! 每件组件的全变体在此陈列——**改矩阵表必须同步本页**（组件库页是活文档）。
//! 页面级文档示例（app_bar / settings / dashboard 预设）后续批次补。
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_button.dart';
import '../../../design/widgets/app_chip.dart';
import '../../../design/widgets/app_progress_bar.dart';
import '../../../design/widgets/app_stat_block.dart';
import '../gallery_parts.dart';

class VariantMatrixDemo extends StatelessWidget {
  const VariantMatrixDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GalleryGroup(title: '变体矩阵 · AppButton（variant × size）', children: [
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            AppButton(label: 'primary', variant: AppButtonVariant.primary),
            AppButton(label: 'outline', variant: AppButtonVariant.outline),
            AppButton(label: 'ghost', variant: AppButtonVariant.ghost),
            AppButton(label: 'danger', variant: AppButtonVariant.danger),
            AppButton(label: 'primary sm', size: AppButtonSize.sm),
            AppButton(label: '带图标', icon: LucideIcons.play),
            AppButton(label: '禁用', onPressed: null),
          ]),
        ]),
        const GalleryGroup(title: '变体矩阵 · AppChip（variant × tone）', children: [
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            AppChip(label: 'solidTint · normal'),
            AppChip(label: 'solidTint · busy', tone: AppChipTone.busy),
            AppChip(label: 'solidTint · error', tone: AppChipTone.error),
            AppChip(label: 'outline', variant: AppChipVariant.outline),
            AppChip(label: 'dot', variant: AppChipVariant.dot),
            AppChip(label: 'md 尺寸', size: AppChipSize.md, showDot: false),
          ]),
        ]),
        const GalleryGroup(title: '变体矩阵 · AppStatBlock（size）', children: [
          Row(children: [
            Expanded(child: AppStatBlock(label: '内存占用', value: '402', unit: 'MB')),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppStatBlock(
                  label: '底座进程', value: '2', unit: '个', size: AppStatBlockSize.sm),
            ),
          ]),
        ]),
        const GalleryGroup(title: '变体矩阵 · AppProgressBar', children: [
          AppProgressBar(value: 0.62, caption: '62%'),
          SizedBox(height: AppSpacing.sm),
          AppProgressBar(caption: '不确定进度（呼吸条）'),
        ]),
      ],
    );
  }
}

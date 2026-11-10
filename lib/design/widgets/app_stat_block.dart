//! AppStatBlock（DESIGN.md · stat-block）：仪表盘数据卡。
//!
//! display 大数字 + label-sm 标签；size 决定数字档（sm 25 / md 36）。
//! 页面不再自建数据卡（linux_base 页的私有 _StatBlock 迁移至此）。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

enum AppStatBlockSize {
  /// display 25（紧凑三列）
  sm,

  /// display 36（大数字）
  md,
}

class AppStatBlock extends StatelessWidget {
  const AppStatBlock({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.size = AppStatBlockSize.md,
  });

  final String label;
  final String value;

  /// 单位小字（secondary，数字后随行）
  final String? unit;
  final AppStatBlockSize size;

  @override
  Widget build(BuildContext context) {
    final numStyle = size == AppStatBlockSize.md
        ? AppTypography.display
        : AppTypography.display.copyWith(fontSize: 25);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: numStyle),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(unit!, style: AppTypography.labelSm),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

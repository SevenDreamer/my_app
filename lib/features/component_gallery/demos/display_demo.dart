//! 展示样张：ShadCard/ShadBadge/ShadAlert/ShadSeparator/ShadProgress
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design/tokens.dart';

class DisplayDemo extends StatelessWidget {
  const DisplayDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          ShadCard(
            width: double.infinity,
            child: Text('ShadCard 卡片容器'),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ShadBadge(child: Text('ShadBadge')),
              ShadBadge.secondary(child: Text('secondary')),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ShadAlert(
            icon: Icon(LucideIcons.info, size: 16),
            title: Text('ShadAlert'),
            description: Text('提示信息：图标 + 标题 + 说明'),
          ),
          SizedBox(height: AppSpacing.sm),
          ShadSeparator.horizontal(),
          SizedBox(height: AppSpacing.sm),
          ShadProgress(value: 0.6),
          SizedBox(height: 2),
          Text('ShadProgress 60%', style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

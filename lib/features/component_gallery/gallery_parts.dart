//! 组件库共享行样式：分组卡片 / demo 行 / 组内分割线
//!
//! 对齐功能页的卡片风格（边框容器 + 内缩分割线），只吃 tokens。
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';

/// 分组卡片：边框容器 + 标题 + 内容行
class GalleryGroup extends StatelessWidget {
  const GalleryGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(title, style: AppTypography.labelSm),
          ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// 单个 demo 行：左侧名称/规格，右侧示例
class GalleryDemoRow extends StatelessWidget {
  const GalleryDemoRow({
    super.key,
    required this.name,
    required this.spec,
    required this.demo,
  });

  final String name;
  final String spec;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyMd),
                const SizedBox(height: 2),
                Text(spec, style: AppTypography.labelSm),
              ],
            ),
          ),
          demo,
        ],
      ),
    );
  }
}

/// 组内分割线（内缩）
class GalleryRowDivider extends StatelessWidget {
  const GalleryRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: AppSpacing.md),
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }
}

//! 被控端页面族共用的小部件：卡片容器 + 空态提示
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';

/// 卡片容器：标题 + 内容列表
class HostCard extends StatelessWidget {
  const HostCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// 空态/占位提示
class HostHint extends StatelessWidget {
  const HostHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.secondary),
    );
  }
}

/// 小号操作按钮（主/次两态）
class HostActionButton extends StatelessWidget {
  const HostActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary ? AppColors.primary : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

//! 组件库：分节（方案页/设置页的内容分组）
//!
//! 小节标题 + 若干内容块，间距遵循 DESIGN.md · Layout（8pt 网格）。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  /// 小节标题
  final String title;

  /// 小节内容
  final List<Widget> children;

  /// 标题行右侧附加内容（可选）
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// 分节内的列表条目（圆点前缀）
class AppBullet extends StatelessWidget {
  const AppBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// 分节内的正文段落
class AppParagraph extends StatelessWidget {
  const AppParagraph(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text),
    );
  }
}

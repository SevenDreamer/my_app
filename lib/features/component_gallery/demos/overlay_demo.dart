//! 弹层样张：ShadDialog/ShadSheet/ShadTooltip（可触发）
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design/tokens.dart';

class OverlayDemo extends StatelessWidget {
  const OverlayDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ShadButton.outline(
            onPressed: () => showShadDialog(
              context: context,
              builder: (ctx) => ShadDialog(
                title: const Text('ShadDialog'),
                description: const Text('模态对话框示例'),
                actions: [
                  ShadButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('知道了')),
                ],
              ),
            ),
            child: const Text('Dialog'),
          ),
          ShadButton.outline(
            onPressed: () => showShadSheet(
              context: context,
              side: ShadSheetSide.bottom,
              builder: (ctx) => const ShadSheet(
                title: Text('ShadSheet'),
                description: Text('底部弹层示例'),
                child: SizedBox(height: 80),
              ),
            ),
            child: const Text('Sheet'),
          ),
          ShadTooltip(
            builder: (context) => const Text('ShadTooltip 悬停提示'),
            child: ShadButton.ghost(
                onPressed: () {}, child: const Text('Tooltip')),
          ),
        ],
      ),
    );
  }
}

//! 按钮样张：ShadButton 各 variant + ShadIconButton
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design/tokens.dart';

class ButtonDemo extends StatelessWidget {
  const ButtonDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ShadButton(
            onPressed: () {},
            leading: const Icon(LucideIcons.plus, size: 16),
            child: const Text('ShadButton'),
          ),
          ShadButton.outline(onPressed: () {}, child: const Text('outline')),
          ShadButton.destructive(
              onPressed: () {}, child: const Text('destructive')),
          ShadButton.ghost(onPressed: () {}, child: const Text('ghost')),
          ShadIconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

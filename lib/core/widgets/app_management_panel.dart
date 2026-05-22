import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/widgets/app_card.dart';

/// 应用管理面板
class AppManagementPanel extends StatelessWidget {
  const AppManagementPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '应用管理',
                style: Theme.of(context).typography.h3,
              ),
              Button.outline(
                child: const Icon(LucideIcons.plus, size: 18),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard.low(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.appWindow,
                      size: 48,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '应用管理功能开发中',
                      style: Theme.of(context).typography.base.copyWith(
                            color:
                                Theme.of(context).colorScheme.mutedForeground,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

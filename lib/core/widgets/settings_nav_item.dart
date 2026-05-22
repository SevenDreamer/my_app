import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 设置导航项组件
class SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback? onTap;

  const SettingsNavItem({
    required this.icon,
    required this.title,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withAlpha(20)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.mutedForeground,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: Theme.of(context).typography.base.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

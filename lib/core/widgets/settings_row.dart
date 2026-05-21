import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 设置行组件
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.mutedForeground.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).typography.base),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).typography.small.copyWith(
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
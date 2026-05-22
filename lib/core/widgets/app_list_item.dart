import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sub_app_shared/sub_app_shared.dart';

/// 应用列表项（单列模式：图标在左，文字在右，紧凑易操作）
class AppListItem extends StatelessWidget {
  final SubApp app;
  final VoidCallback? onTap;

  const AppListItem({
    required this.app,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: app.color.withalues(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  app.icon,
                  size: 28,
                  color: app.color,
                ),
              ),
              const SizedBox(width: 20),
              // 右侧文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

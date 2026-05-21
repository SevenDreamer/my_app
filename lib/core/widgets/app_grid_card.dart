import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';

/// 应用网格卡片（多列模式：图标在上，文字在下）
class AppGridCard extends StatelessWidget {
  final SubApp app;
  final VoidCallback? onTap;

  const AppGridCard({
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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                app.icon,
                size: 40,
                color: app.color,
              ),
              const SizedBox(height: 12),
              Text(
                app.name,
                style: Theme.of(context).typography.h3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  app.description,
                  style: Theme.of(context).typography.small,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

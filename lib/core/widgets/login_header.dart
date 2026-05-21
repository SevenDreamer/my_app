import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:my_app/core/config/app_config.dart';

/// 登录页头部：图标 + 标题
/// 配置来自 [AppConfig]
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          LucideIcons.lock,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(AppConfig.loginTitle, style: theme.typography.h1),
      ],
    );
  }
}

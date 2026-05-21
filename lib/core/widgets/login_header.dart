import 'package:flutter/material.dart' hide ButtonStyle, Card;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:my_app/core/config/app_config.dart';

/// 登录页头部：图标 + 标题
/// 配置来自 [AppConfig]
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    return Column(
      children: [
        shadcn.Icon(
          const IconData(AppConfig.loginIconCodePoint, fontFamily: 'LucideIcons'),
          size: 48,
          color: theme.colorScheme.primary,
        ),  // ignore: prefer_const_constructors
        const SizedBox(height: 24),
        Text(AppConfig.loginTitle, style: theme.typography.h1),
      ],
    );
  }
}

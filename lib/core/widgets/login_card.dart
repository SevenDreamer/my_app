import 'package:flutter/material.dart' hide Card, ButtonStyle;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'package:my_app/core/widgets/login_header.dart';
import 'package:my_app/core/widgets/login_text_field.dart';
import 'package:my_app/core/widgets/submit_button.dart';
import 'package:my_app/core/widgets/error_message.dart';

/// 登录卡片：组合 LoginHeader / LoginTextField / SubmitButton / ErrorMessage
/// 使用 shadcn_flutter Card 组件
class LoginCard extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;

  const LoginCard({
    super.key,
    required this.isLoading,
    this.errorMessage,
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LoginHeader(),
            const SizedBox(height: 32),
            LoginTextField(
              controller: usernameController,
              label: '用户名',
              leading: const shadcn.Icon(shadcn.LucideIcons.user, size: 18),
              enabled: !isLoading,
              onSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 16),
            LoginTextField(
              controller: passwordController,
              label: '密码',
              leading: const shadcn.Icon(shadcn.LucideIcons.lock, size: 18),
              obscureText: true,
              enabled: !isLoading,
              onSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 24),
            SubmitButton(isLoading: isLoading, onPressed: onLogin),
            ErrorMessage(message: errorMessage),
          ],
        ),
      ),
    );
  }
}

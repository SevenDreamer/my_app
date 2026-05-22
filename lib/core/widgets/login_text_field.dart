import 'package:flutter/material.dart' hide ButtonStyle, Card;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// 统一风格的登录输入框
/// 基于 Material TextField，但使用 shadcn 色彩系统
class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? leading;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    this.leading,
    this.obscureText = false,
    this.enabled = true,
    this.onSubmitted,
  }); // ignore: always_put_required_named_parameters_first

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: leading,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius * 8),
        ),
      ),
    );
  }
}

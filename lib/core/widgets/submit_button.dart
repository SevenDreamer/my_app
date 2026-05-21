import 'package:flutter/material.dart' hide ButtonStyle, Card, CircularProgressIndicator;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// 基于 shadcn_flutter Button 的提交按钮
/// 支持 loading 状态，自动显示 CircularProgressIndicator
class SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final shadcn.ButtonStyle? style;
  final Widget? leading;

  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.label = '登录',
    this.style,
    this.leading,
  });  // ignore: always_put_required_named_parameters_first

  @override
  Widget build(BuildContext context) {
    return shadcn.Button(
      onPressed: isLoading ? null : onPressed,
      style: style ?? const shadcn.ButtonStyle.primary(),
      leading: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: shadcn.CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : leading,
      child: Text(label),
    );
  }
}

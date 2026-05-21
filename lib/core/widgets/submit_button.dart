import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 基于 shadcn_flutter Button 的提交按钮
/// 支持 loading 状态，自动显示 CircularProgressIndicator
class SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final ButtonStyle? style;
  final Widget? leading;

  const SubmitButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.label = '登录',
    this.style,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      onPressed: isLoading ? null : onPressed,
      leading: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
          : leading,
      child: Text(label).bold(),
    );
  }
}

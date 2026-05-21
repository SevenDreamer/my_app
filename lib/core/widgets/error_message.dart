import 'package:flutter/material.dart' hide ButtonStyle, Card;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// 错误提示，使用 shadcn_flutter Alert 组件
class ErrorMessage extends StatelessWidget {
  final String? message;

  const ErrorMessage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        shadcn.Alert(
          title: const Text('错误'),
          content: Text(message!),
          // shadcn Alert 默认有样式，可以根据需要自定义
        ),
      ],
    );
  }
}

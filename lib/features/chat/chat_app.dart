import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/app_router.dart';

/// 聊天助手子应用
class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.go(AppRoutes.launcher),
            ),
          ],
          title: const Text('聊天助手'),
        ),
      ],
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.messageCircle,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text('聊天助手').h2(),
                const SizedBox(height: 8),
                const Text('AI 智能对话助手').muted(),
                const SizedBox(height: 32),
                const Text('功能开发中...').small(),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: () {
                    // TODO: 实现聊天功能
                  },
                  child: const Text('开始对话'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

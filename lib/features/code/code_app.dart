import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 代码助手子应用
class CodeApp extends StatelessWidget {
  const CodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: const Text('代码助手'),
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
                  LucideIcons.code,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text('代码助手').h2(),
                const SizedBox(height: 8),
                const Text('AI 代码生成与优化').muted(),
                const SizedBox(height: 32),
                const Text('功能开发中...').small(),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: () {
                    // TODO: 实现代码生成功能
                  },
                  child: const Text('生成代码'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

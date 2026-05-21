import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/app_router.dart';

/// 图片处理子应用
class ImageApp extends StatelessWidget {
  const ImageApp({super.key});

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
          title: const Text('图片处理'),
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
                  LucideIcons.image,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text('图片处理').h2(),
                const SizedBox(height: 8),
                const Text('AI 图片编辑工具').muted(),
                const SizedBox(height: 32),
                const Text('功能开发中...').small(),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: () {
                    // TODO: 实现图片处理功能
                  },
                  child: const Text('选择图片'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

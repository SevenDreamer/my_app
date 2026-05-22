// 图片处理子应用 - 实现 SubApp 接口
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sub_app_shared/sub_app_shared.dart';

/// 图片处理子应用
class ImageSubApp implements SubApp {
  const ImageSubApp();

  @override
  String get id => 'image';

  @override
  String get name => '图片处理';

  @override
  String get route => '/image';

  @override
  IconData get icon => LucideIcons.image;

  @override
  IconData? get activeIcon => LucideIcons.image;

  @override
  String get description => 'AI 图片编辑工具';

  @override
  bool get requiresAuth => false;

  @override
  String get version => '1.0.0';

  @override
  Widget builder(BuildContext context) {
    return const ImageApp();
  }
}

/// 图片处理应用主组件
class ImageApp extends StatelessWidget {
  const ImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.go('/'),
          ),
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
                Text(
                  '图片处理',
                  style: Theme.of(context).typography.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'AI 图片编辑工具',
                  style: Theme.of(context).typography.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.mutedForeground,
                      ),
                ),
                const SizedBox(height: 32),
                Text(
                  '功能开发中...',
                  style: Theme.of(context).typography.bodySmall,
                ),
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

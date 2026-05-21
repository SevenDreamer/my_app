import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/app_router.dart';

/// 应用管理界面（仅管理员）
/// TODO(v_qzxgqiu, 2026-05-30): 待实现 flutter_rust_bridge 认证 API 后完善
class AppManagementScreen extends StatelessWidget {
  const AppManagementScreen({super.key});

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
          title: const Text('应用管理'),
          trailing: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.plus),
              onPressed: () {
                // TODO(v_qzxgqiu, 2026-05-30): 实现添加应用功能
              },
            ),
          ],
        ),
      ],
      child: const Center(
        child: Text('暂无应用，功能开发中'),
      ),
    );
  }
}

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/app_router.dart';

/// 用户管理界面（仅管理员）
/// TODO(v_qzxgqiu, 2026-05-30): 待实现 flutter_rust_bridge 用户管理 API 后完善
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

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
          title: const Text('用户管理'),
        ),
      ],
      child: const Center(
        child: Text('用户管理 - 待重构（使用 flutter_rust_bridge）'),
      ),
    );
  }
}

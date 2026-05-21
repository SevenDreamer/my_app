import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/features/database/screens/database_manager_screen.dart';

/// 数据库管理子应用入口
class DatabaseManagerApp extends StatelessWidget {
  const DatabaseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('数据库管理'),
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.go(AppRoutes.launcher),
            ),
          ],
        ),
      ],
      child: const DatabaseManagerScreen(),
    );
  }
}

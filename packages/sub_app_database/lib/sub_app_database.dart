// 数据库管理子应用 - 实现 SubApp 接口
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:sub_app_shared/sub_app_shared.dart';

import 'screens/database_manager_screen.dart';

/// 数据库管理子应用
class DatabaseSubApp implements SubApp {
  const DatabaseSubApp();

  @override
  String get id => 'database';

  @override
  String get name => '数据库管理';

  @override
  String get route => '/database';

  @override
  IconData get icon => LucideIcons.database;

  @override
  IconData? get activeIcon => LucideIcons.database;

  @override
  String get description => '连接并管理多种数据库（SQLite/MySQL/PostgreSQL/MongoDB）';

  @override
  bool get requiresAuth => false;

  @override
  String get version => '1.0.0';

  @override
  Widget builder(BuildContext context) {
    return const DatabaseManagerApp();
  }
}

/// 数据库管理应用主组件
class DatabaseManagerApp extends StatelessWidget {
  const DatabaseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.go('/'),
          ),
          title: const Text('数据库管理'),
        ),
      ],
      child: const DatabaseManagerScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/database_manager_screen.dart';

/// 数据库管理子应用入口
class DatabaseManagerApp extends StatelessWidget {
  const DatabaseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const DatabaseManagerScreen(),
    );
  }
}

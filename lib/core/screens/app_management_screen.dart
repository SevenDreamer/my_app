import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// 应用管理界面（仅管理员）
/// TODO: 待实现 flutter_rust_bridge 认证 API 后完善
class AppManagementScreen extends StatefulWidget {
  final String token;

  const AppManagementScreen({super.key, required this.token});

  @override
  State<AppManagementScreen> createState() => _AppManagementScreenState();
}

class _AppManagementScreenState extends State<AppManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用管理'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('功能开发中')),
              );
            },
            tooltip: '添加应用',
          ),
        ],
      ),
      body: const Center(
        child: Text('暂无应用，功能开发中'),
      ),
    );
  }
}

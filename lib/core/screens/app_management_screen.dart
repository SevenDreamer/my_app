import 'package:shadcn_flutter/shadcn_flutter.dart';

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
      headers: [
        AppBar(
          title: const Text('应用管理'),
          trailing: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.plus),
              onPressed: () {
                // TODO: 实现添加应用功能
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

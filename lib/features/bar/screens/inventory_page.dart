import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:lucide_flutter/lucide_flutter.dart';

/// 库存管理页面（使用 shadcn_flutter，无 Scaffold）
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(
          child: Text('库存管理'),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: shadcn.PrimaryButton(
            onPressed: () {
              // 使用 GoRouter 导航到添加记录页面
              context.pushNamed('add-record');
            },
            child: const Icon(LucideIcons.plus, size: 20),
          ),
        ),
      ],
    );
  }
}

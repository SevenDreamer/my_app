import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:lucide_flutter/lucide_flutter.dart';
import 'add_record_page.dart';

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddRecordPage()),
              );
            },
            child: const Icon(LucideIcons.plus, size: 20),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'add_record_page.dart';

/// 库存管理页面
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('库存管理'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddRecordPage()),
          );
        },
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}
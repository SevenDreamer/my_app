import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../bar/screens/inventory_page.dart';
import '../bar/screens/settings_page.dart';

/// 酒吧系统子应用
class BarApp extends StatefulWidget {
  const BarApp({super.key});

  @override
  State<BarApp> createState() => _BarAppState();
}

class _BarAppState extends State<BarApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('酒吧管理系统'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: [
        const InventoryPage(),
        const SettingsPage(),
      ][_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.package),
            label: '库存管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
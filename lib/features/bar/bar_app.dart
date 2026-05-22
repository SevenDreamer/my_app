import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/features/bar/screens/inventory_page.dart';
import 'package:my_app/features/bar/screens/settings_page.dart';

/// 底部导航栏
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _BottomNavItem(icon: LucideIcons.wallet, label: '库存管理'),
    _BottomNavItem(icon: LucideIcons.settings, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            _BottomNavItemWidget(
              item: _items[i],
              selected: i == currentIndex,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _BottomNavItemWidget extends StatelessWidget {
  const _BottomNavItemWidget({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = selected
        ? colorScheme.primary
        : colorScheme.foreground.withValues(alpha: 0.6);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: theme.typography.small.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 酒吧系统主页面（底部导航壳）
class BarApp extends StatefulWidget {
  const BarApp({super.key});

  @override
  State<BarApp> createState() => _BarAppState();
}

class _BarAppState extends State<BarApp> {
  int _currentIndex = 0;

  final _pages = const <Widget>[
    InventoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Column(
        children: [
          Expanded(child: _pages[_currentIndex]),
          _BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        ],
      ),
    );
  }
}

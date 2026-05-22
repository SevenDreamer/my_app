import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/hermes/screens/sessions_screen.dart';
import 'package:my_app/features/hermes/screens/skills_screen.dart';
import 'package:my_app/features/hermes/screens/models_screen.dart';
import 'package:my_app/features/hermes/screens/cron_screen.dart';

/// Hermes AI 助手子应用入口
class HermesApp extends StatefulWidget {
  const HermesApp({super.key});

  @override
  State<HermesApp> createState() => _HermesAppState();
}

class _HermesAppState extends State<HermesApp> {
  int _selectedIndex = 0;

  final _pages = const <Widget>[
    SessionsScreen(),
    SkillsScreen(),
    ModelsScreen(),
    CronScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Hermes AI'),
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.go('/launcher'),
            ),
          ],
        ),
      ],
      child: Row(
        children: [
          // 侧边栏
          Container(
            width: 160,
            decoration: const BoxDecoration(
              color: obsidianSurface,
              border: Border(
                right: BorderSide(color: obsidianBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _SidebarButton(
                  icon: LucideIcons.messageCircle,
                  label: '会话',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _SidebarButton(
                  icon: LucideIcons.sparkles,
                  label: '技能',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _SidebarButton(
                  icon: LucideIcons.cloud,
                  label: '模型',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _SidebarButton(
                  icon: LucideIcons.clock,
                  label: '定时',
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
          // 主内容区
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? obsidianAccent.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? obsidianAccent : obsidianTextMuted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? obsidianAccent : obsidianTextMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

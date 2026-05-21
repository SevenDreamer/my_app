import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/widgets/app_card.dart';
import 'package:my_app/core/widgets/settings_nav_item.dart';
import 'package:my_app/core/widgets/general_settings_panel.dart';
import 'package:my_app/core/widgets/user_management_panel.dart';
import 'package:my_app/core/widgets/app_management_panel.dart';

/// 设置界面（平板左右布局）
///
/// 左侧：导航菜单
/// 右侧：设置内容
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _username = '用户';
  String _role = 'user';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '用户';
      _role = prefs.getString('role') ?? 'user';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role');

    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _role == 'admin';

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.go(AppRoutes.launcher),
            ),
          ],
          title: const Text('设置'),
        ),
      ],
      child: Container(
        color: Theme.of(context).colorScheme.muted.withAlpha(15),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧导航栏
            SizedBox(
              width: 280,
              child: AppCard(
                child: Column(
                  children: [
                    // 用户信息
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              LucideIcons.user,
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _username,
                                  style: Theme.of(context).typography.base.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  isAdmin ? '管理员' : '普通用户',
                                  style: Theme.of(context).typography.small.copyWith(
                                        color: Theme.of(context).colorScheme.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // 导航菜单
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          SettingsNavItem(
                            icon: LucideIcons.settings,
                            title: '通用设置',
                            isSelected: _selectedIndex == 0,
                            onTap: () => setState(() => _selectedIndex = 0),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 4),
                            SettingsNavItem(
                              icon: LucideIcons.users,
                              title: '用户管理',
                              isSelected: _selectedIndex == 1,
                              onTap: () => setState(() => _selectedIndex = 1),
                            ),
                            const SizedBox(height: 4),
                            SettingsNavItem(
                              icon: LucideIcons.appWindow,
                              title: '应用管理',
                              isSelected: _selectedIndex == 2,
                              onTap: () => setState(() => _selectedIndex = 2),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(),
                    // 退出登录
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Button.destructive(
                          onPressed: _logout,
                          child: const Text('退出登录'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 右侧内容区
            Expanded(
              child: AppCard(
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 1:
        return const UserManagementPanel();
      case 2:
        return const AppManagementPanel();
      default:
        return const GeneralSettingsPanel();
    }
  }
}

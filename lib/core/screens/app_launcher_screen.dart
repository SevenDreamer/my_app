import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/core/screens/app_launcher/app_data.dart';
import 'package:my_app/core/screens/app_launcher/app_list_item.dart';
import 'package:my_app/core/screens/app_launcher/app_grid_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
///
/// 响应式布局：
/// - 窄屏（< 560px）：列表模式，图标在左文字在右
/// - 宽屏（>= 560px）：网格模式，图标在上文字在下
class AppLauncherScreen extends StatefulWidget {
  final String? token;
  final String username;
  final String role;

  const AppLauncherScreen({
    super.key,
    this.token,
    this.username = '用户',
    this.role = 'user',
  });

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text('欢迎，${widget.username}'),
          trailing: [
            if (widget.role == 'admin')
              IconButton(
                variance: ButtonVariance.ghost,
                icon: const Icon(LucideIcons.settings),
                onPressed: _onSettingsPressed,
              ),
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.logOut),
              onPressed: _logout,
            ),
          ],
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择应用',
              style: Theme.of(context).typography.h2,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 响应式：根据可用宽度决定布局模式
                  // 宽度 < 560：列表模式（单列，横向布局）
                  // 宽度 >= 560：网格模式（多列卡片）
                  const minCardWidth = 280.0;
                  final crossAxisCount =
                      (constraints.maxWidth / minCardWidth).floor().clamp(1, 4);
                  final isListMode = crossAxisCount == 1;

                  if (isListMode) {
                    return ListView.separated(
                      itemCount: builtInApps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => AppListItem(
                        app: builtInApps[index],
                        onTap: () => _onAppTap(builtInApps[index]),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: builtInApps.length,
                    itemBuilder: (context, index) => AppGridCard(
                      app: builtInApps[index],
                      onTap: () => _onAppTap(builtInApps[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击设置（管理员）
  void _onSettingsPressed() {
    // TODO(v_qzxgqiu, 2026-05-30): 实现管理功能
  }

  /// 点击应用卡片/列表项
  void _onAppTap(SubApp app) {
    // TODO(v_qzxgqiu, 2026-05-30): 导航到对应的应用页面
    print('打开应用: ${app.name}');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (mounted) {
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

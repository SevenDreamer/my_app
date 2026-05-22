import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/core/models/app_data.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/widgets/app_grid_card.dart';
import 'package:my_app/core/widgets/app_list_item.dart';
import 'package:my_app/core/config/feature_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
///
/// 响应式布局：
/// - 窄屏（< 560px）：列表模式，图标在左文字在右
/// - 宽屏（>= 560px）：网格模式，图标在上文字在下
class AppLauncherScreen extends StatefulWidget {
  const AppLauncherScreen({super.key});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  String _username = '用户';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '用户';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: Text('欢迎，$_username'),
          trailing: [
            IconButton(
              variance: ButtonVariance.ghost,
              icon: const Icon(LucideIcons.settings),
              onPressed: _onSettingsPressed,
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

                  final apps = FeatureRegistry.visibleApps;

                  if (isListMode) {
                    return ListView.separated(
                      itemCount: apps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => AppListItem(
                        app: apps[index],
                        onTap: () => _onAppTap(apps[index]),
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
                    itemCount: apps.length,
                    itemBuilder: (context, index) => AppGridCard(
                      app: apps[index],
                      onTap: () => _onAppTap(apps[index]),
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

  /// 点击设置
  void _onSettingsPressed() {
    context.go(AppRoutes.settings);
  }

  /// 点击应用卡片/列表项
  void _onAppTap(SubApp app) {
    // 使用 GoRouter 命名路由导航到对应的应用页面
    final builder = FeatureRegistry.getBuilder(app.id);
    if (builder != null) {
      // 如果有注册的 builder，使用它
      context.go(app.route);
    } else {
      // 否则直接跳转路由
      context.go(app.route);
    }
  }
}

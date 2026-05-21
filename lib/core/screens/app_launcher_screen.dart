import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
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
  /// 内置子应用列表（MVP方案：所有子应用内置在主应用中）
  final List<SubApp> _apps = const [
    SubApp(
      id: 'image',
      name: '图片处理',
      description: 'AI 图片生成与编辑',
      iconName: 'image',
      color: Color(0xFF57A6FF),
      route: '/image',
    ),
    SubApp(
      id: 'chat',
      name: '智能对话',
      description: 'AI 助手对话',
      iconName: 'message_circle',
      color: Color(0xFF7C5CFC),
      route: '/chat',
    ),
    SubApp(
      id: 'code',
      name: '代码助手',
      description: 'AI 代码生成与审查',
      iconName: 'code2',
      color: Color(0xFF4ECDC4),
      route: '/code',
    ),
    SubApp(
      id: 'bar',
      name: '酒吧管理',
      description: '酒吧库存与销售管理',
      iconName: 'wine',
      color: Color(0xFFE8AA42),
      route: '/bar',
    ),
    SubApp(
      id: 'database',
      name: '数据库连接',
      description: '管理数据库连接',
      iconName: 'database',
      color: Color(0xFFFF6B6B),
      route: '/database',
    ),
  ];

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
                onPressed: () {
                  // TODO: 实现管理功能
                },
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
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  return _buildAppCard(app);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建应用卡片
  Widget _buildAppCard(SubApp app) {
    return Card(
      child: GestureDetector(
        onTap: () {
          // TODO: 导航到对应的应用页面
          print('打开应用: ${app.name}');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                app.icon,
                size: 48,
                color: app.color,
              ),
              const SizedBox(height: 16),
              Text(
                app.name,
                style: Theme.of(context).typography.h3,
              ),
              const SizedBox(height: 8),
              Text(
                app.description,
                style: Theme.of(context).typography.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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

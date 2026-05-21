import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
/// TODO: 待实现应用列表查询
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
      child: const Center(
        child: Text('暂无可用应用'),
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

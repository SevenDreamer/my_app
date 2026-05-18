import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/features/chat/chat_app.dart';
import 'package:my_app/features/image/image_app.dart';
import 'package:my_app/features/code/code_app.dart';
import 'package:my_app/features/database/database_app.dart';
import 'package:my_app/features/bar/bar_app.dart';
import 'package:my_app/core/screens/login_screen.dart';
import '../rust/ffi_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用启动器（主界面）
class AppLauncherScreen extends StatefulWidget {
  final String? token;

  const AppLauncherScreen({super.key, this.token});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  List<SubApp> _apps = [];
  bool _isLoading = true;
  String _currentToken = '';
  String _username = '';
  String _role = '';

  // 所有可用的子应用
  final List<SubApp> _allApps = [
    const SubApp(
      id: 'chat',
      name: '聊天助手',
      description: 'AI 智能对话助手',
      icon: LucideIcons.messageCircle,
      color: Color(0xFF7C5CFC),
      builder: ChatApp.new,
    ),
    const SubApp(
      id: 'image',
      name: '图片处理',
      description: 'AI 图片编辑工具',
      icon: LucideIcons.image,
      color: Color(0xFF57A6FF),
      builder: ImageApp.new,
    ),
    const SubApp(
      id: 'code',
      name: '代码助手',
      description: 'AI 代码生成与优化',
      icon: LucideIcons.code2,
      color: Color(0xFF4ECDC4),
      builder: CodeApp.new,
    ),
    const SubApp(
      id: 'database',
      name: '数据库管理',
      description: '数据库浏览与管理工具',
      icon: LucideIcons.database,
      color: Color(0xFFFF6B6B),
      builder: DatabaseManagerApp.new,
    ),
    const SubApp(
      id: 'bar',
      name: '酒吧系统',
      description: '酒吧点单与管理',
      icon: LucideIcons.wine,
      color: Color(0xFFE8AA42),
      builder: BarApp.new,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token ?? '';
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });

    if (_currentToken.isEmpty) {
      // 未登录，跳转到登录界面
      _logout();
      return;
    }

    // 获取用户信息
    final userResult = AuthFFI.instance.getCurrentUser(_currentToken);
    final userData = jsonDecode(userResult);
    if (userData['ok'] != true) {
      // Token 无效，跳转到登录界面
      _logout();
      return;
    }

    setState(() {
      _username = userData['username'] ?? '';
      _role = userData['role'] ?? 'user';
    });

    // 获取应用列表
    final result = AuthFFI.instance.getApps(_currentToken);
    final data = jsonDecode(result);

    if (data['ok'] == true) {
      final appList = data['data'] as List<dynamic>;
      final appIds = appList.map((app) => app['app_name'] as String).toSet();

      setState(() {
        if (_role == 'admin') {
          // 管理员可以看到所有应用
          _apps = List.from(_allApps);
        } else {
          // 普通用户只能看到被分配的应用
          _apps = _allApps.where((app) => appIds.contains(app.id)).toList();
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _apps = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_currentToken.isNotEmpty) {
      AuthFFI.instance.logout(_currentToken);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('欢迎，$_username'),
        centerTitle: false,
        actions: [
          if (_role == 'admin')
            IconButton(
              icon: const Icon(LucideIcons.users),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UserManagementScreen(token: _currentToken),
                  ),
                );
              },
              tooltip: '用户管理',
            ),
          IconButton(
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
            tooltip: '登出',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? const Center(child: Text('没有可用的应用'))
              : Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 子应用列表
                      Expanded(
                        child: ListView.separated(
                          itemCount: _apps.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final app = _apps[index];
                            return _AppCard(app: app);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// 子应用列表项（简洁风格）
class _AppCard extends StatelessWidget {
  final SubApp app;

  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return HeroUiCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => app.builder()),
        );
      },
      borderRadius: 12,
      showShadow: false,
      borderColor: Colors.transparent,
      body: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: app.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(app.icon, size: 22, color: app.color),
          ),
          const SizedBox(width: 16),

          // 应用名称
          Expanded(
            child: Text(
              app.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heroui_design_system/heroui_design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:my_app/core/models/sub_app.dart';
import 'package:my_app/core/routing/app_router.dart';
import 'package:my_app/core/screens/login_screen.dart';
import 'package:my_app/core/screens/user_management_screen.dart';
import 'package:my_app/core/screens/app_management_screen.dart';
import 'package:my_app/rust/ffi_auth.dart';
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
      _logout();
      return;
    }

    // 获取用户信息
    final userResult = AuthFFI.instance.getCurrentUser(_currentToken);
    final userData = jsonDecode(userResult);
    if (userData['ok'] != true) {
      _logout();
      return;
    }

    setState(() {
      _username = (userData['username'] ?? '') as String;
      _role = (userData['role'] ?? 'user') as String;
    });

    // 获取应用列表
    final result = AuthFFI.instance.getApps(_currentToken);
    final data = jsonDecode(result);

    if (data['ok'] == true) {
      final appList = data['data'] as List<dynamic>;

      setState(() {
        _apps = appList
            .map((app) => SubApp.fromJson(app as Map<String, dynamic>))
            .where((app) => app.isEnabled)
            .toList();
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
      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (context) => const LoginScreen()),
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
          if (_role == 'admin') ...[
            IconButton(
              icon: const Icon(LucideIcons.users),
              onPressed: () {
                Navigator.of(context)
                    .push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    )
                    .then((_) => _loadApps()); // 返回时刷新
              },
              tooltip: '用户管理',
            ),
            IconButton(
              icon: const Icon(LucideIcons.appWindow),
              onPressed: () {
                Navigator.of(context)
                    .push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            AppManagementScreen(token: _currentToken),
                      ),
                    )
                    .then((_) => _loadApps()); // 返回时刷新
              },
              tooltip: '应用管理',
            ),
          ],
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
        // 根据路由获取对应的 Widget
        final widget = getWidgetByRoute(app.route);
        if (widget != null) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => widget),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未找到应用：${app.route}')),
          );
        }
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

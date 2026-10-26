//! 手柄控制入口页：角色选择（控制端 / 被控端）
//!
//! 不自动连接——连接动作全部下沉到所选角色页内显式触发。
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'controller_page.dart';
import 'host_page.dart';

class GamepadHomePage extends StatelessWidget {
  const GamepadHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '手柄控制'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择本机在这次连接中的角色。',
              style: TextStyle(fontSize: 12, color: AppColors.secondary),
            ),
            const SizedBox(height: AppSpacing.md),
            _RoleCard(
              title: '控制端',
              subtitle: '把手机变成手柄，向被控端发送按键/摇杆',
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => const ControllerPage(),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _RoleCard(
              title: '被控端',
              subtitle: '搜索并配对手柄，接收手柄操作（本机/游戏）',
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => const HostPage(),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 角色卡：淡底图标块 + 标题 + 说明 + 箭头
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

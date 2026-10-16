//! 主页：底部导航壳（应用主入口）
//!
//! 左=功能列表、中=占位（功能未定）、右=我；功能子页面
//! （机器人眼睛/记事本）以全屏 push 进入，不受底部栏影响。
//! 中间位置等想好用途后替换 _ComingSoonTab 即可。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design/tokens.dart';
import 'features_page.dart';
import 'profile_page.dart';
import 'update/update_notice_dialog.dart';
import 'update/update_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 当前选中的 tab
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  /// 启动 3 秒后静默检查更新：无授权 / 无新版 / 网络问题 / iOS 全部静默，
  /// 仅在发现新版时弹 shadcn 提示框（v1 提示型，见 docs/ROADMAP.md）。
  Future<void> _checkForUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final info = await UpdateService().check();
    if (!mounted || info == null) return;
    await showUpdateNotice(context, info);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 保活三个 tab 的状态（切回不重建）
      body: IndexedStack(
        index: _index,
        children: const [
          FeaturesPage(),
          _ComingSoonTab(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutGrid),
            selectedIcon: Icon(LucideIcons.layoutGrid),
            label: '功能',
          ),
          // 中间占位：暂无标签的图标钮，用途待定
          NavigationDestination(
            icon: Icon(LucideIcons.circlePlus),
            selectedIcon: Icon(LucideIcons.circlePlus),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user),
            label: '我',
          ),
        ],
      ),
    );
  }
}

/// 中间 tab 的占位内容：功能未定，先给提示
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('敬请期待')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                LucideIcons.hardHat,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '这个位置的功能还在想',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

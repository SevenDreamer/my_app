//! Live2D 设置页（方案 B：Linear/Vercel 边框卡片风）——功能入口
//!
//! 两级导航：设置（功能入口）→ 模型选择子页 / 导入模型。
//! 样式为本页私有实现（_SettingRow）——不动公共组件，避免波及「我」页。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design/widgets/app_scaffold.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import 'live2d_model_select_page.dart';

class Live2dSettingsPage extends StatelessWidget {
  const Live2dSettingsPage({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: 'Live2D 设置'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _GroupTitle('功能'),
          _GroupCard(
            children: [
              _SettingRow(
                iconData: LucideIcons.users,
                title: '模型选择',
                subtitle: '切换当前使用的 Live2D 模型',
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      pageBuilder: (_, __, ___) => Live2dModelSelectPage(
                        currentIndex: currentIndex,
                        onSelect: onSelect,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          // 未来扩展：_GroupTitle('显示与交互')（触摸跟随/缩放/动作频率）
        ],
      ),
    );
  }
}

/// 分组标题（卡片外的小标题）
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 分组卡片（1px 边框圆角容器）
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E4E7)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// 设置行（图标方块 + 标题/副标题 + hover 高亮 + chevron）
class _SettingRow extends StatefulWidget {
  const _SettingRow({
    required this.title,
    this.subtitle,
    required this.iconData,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData iconData;
  final VoidCallback? onTap;

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovering ? const Color(0xFFF4F4F5) : const Color(0x00000000),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  border: Border.all(color: const Color(0xFFE4E4E7)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(widget.iconData, size: 13),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71717A),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

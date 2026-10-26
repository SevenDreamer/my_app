//! 组件库页：统一组件与设计规范的实时展示
//!
//! 全仓「去 material」的样板间：本页只用 flutter/widgets + shadcn_ui +
//! design 层，零 Material 引用。
//! 内容对齐 .agents/skills/shadcn-ui-flutter 的组件文档；
//! 间距/圆角/颜色一律引 tokens，不硬编码。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_list_tile.dart';
import '../../design/widgets/app_scaffold.dart';
import '../../design/widgets/app_section.dart';
import '../../design/widgets/app_setting_row.dart';
import '../../design/widgets/app_spinner.dart';
import '../../design/widgets/app_toast.dart';

class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '组件库'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _Group(title: '设计 Tokens', children: [
            _TokensDemo(),
          ]),
          _Group(title: '基础壳（design 层九件套）', children: [
            _ShellDemo(),
          ]),
          _Group(title: '按钮', children: [
            _ButtonDemo(),
          ]),
          _Group(title: '表单', children: [
            _FormDemo(),
          ]),
          _Group(title: '展示', children: [
            _DisplayDemo(),
          ]),
          _Group(title: '弹层与导航', children: [
            _OverlayDemo(),
          ]),
        ],
      ),
    );
  }
}

/// 分组卡片：边框容器 + 标题 + 内容行（对齐功能页的卡片风格）
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(title, style: AppTypography.labelSm),
          ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// 单个 demo 行：左侧名称/规格，右侧示例
class _DemoRow extends StatelessWidget {
  const _DemoRow({
    required this.name,
    required this.spec,
    required this.demo,
  });

  final String name;
  final String spec;
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyMd),
                const SizedBox(height: 2),
                Text(spec, style: AppTypography.labelSm),
              ],
            ),
          ),
          demo,
        ],
      ),
    );
  }
}

/// 组内分割线（内缩）
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: AppSpacing.md),
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }
}

/// 设计 Tokens：颜色 / 间距 / 圆角 / 字号
class _TokensDemo extends StatelessWidget {
  const _TokensDemo();

  @override
  Widget build(BuildContext context) {
    const swatches = <(String, Color)>[
      ('primary', AppColors.primary),
      ('onPrimary', AppColors.onPrimary),
      ('secondary', AppColors.secondary),
      ('neutral', AppColors.neutral),
      ('surface', AppColors.surface),
      ('onSurface', AppColors.onSurface),
      ('error', AppColors.error),
      ('border', AppColors.border),
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 色板
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (name, color) in swatches)
                Column(
                  children: [
                    Container(
                      width: 44,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(name, style: AppTypography.labelSm),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 间距
          const Text('间距 xs/sm/md/lg', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            for (final s in [
              ('xs', AppSpacing.xs),
              ('sm', AppSpacing.sm),
              ('md', AppSpacing.md),
              ('lg', AppSpacing.lg),
            ]) ...[
              Column(children: [
                Container(
                    width: s.$2 * 2, height: 12, color: AppColors.primary),
                Text(s.$1, style: AppTypography.labelSm),
              ]),
              const SizedBox(width: AppSpacing.sm),
            ],
          ]),
          const SizedBox(height: AppSpacing.md),
          // 圆角
          const Text('圆角 sm/md/lg', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            for (final r in [
              ('sm', AppRadius.sm),
              ('md', AppRadius.md),
              ('lg', AppRadius.lg),
            ]) ...[
              Container(
                width: 44,
                height: 28,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(r.$2),
                ),
                alignment: Alignment.center,
                child: Text(r.$1, style: AppTypography.labelSm),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ]),
          const SizedBox(height: AppSpacing.md),
          // 字号
          const Text('h1', style: AppTypography.h1),
          const Text('bodyMd 正文', style: AppTypography.bodyMd),
          const Text('labelSm 辅助说明', style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

/// design 层九件套的规格说明与示例
class _ShellDemo extends StatelessWidget {
  const _ShellDemo();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _DemoRow(
        name: 'AppScaffold + AppHeader',
        spec: '页面壳 + 顶栏（本页就是它搭的）',
        demo: Icon(LucideIcons.layoutGrid, size: 18),
      ),
      const _RowDivider(),
      const _DemoRow(
        name: 'AppSection',
        spec: '内容分区：标题 + children',
        demo: Icon(LucideIcons.fileText, size: 18),
      ),
      const _RowDivider(),
      const _DemoRow(
        name: 'AppListTile',
        spec: '列表行：图标块 + 标题/副标题 + 尾随',
        demo: Icon(LucideIcons.menu, size: 18),
      ),
      const _RowDivider(),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AppListTile(
          icon: LucideIcons.users,
          title: 'AppListTile 示例',
          subtitle: '设备名 · 状态说明',
          trailing: Icon(LucideIcons.chevronRight, size: 16),
        ),
      ),
      const _RowDivider(),
      const _DemoRow(
        name: 'AppSettingRow',
        spec: '设置行：标题 + 说明 + 尾随（Stateful）',
        demo: Icon(LucideIcons.settings, size: 18),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AppSettingRow(
          icon: LucideIcons.settings,
          title: 'AppSettingRow 示例',
          detail: '设置行说明文字',
          trailing: Icon(LucideIcons.chevronRight, size: 16),
          showDivider: false,
        ),
      ),
      const _RowDivider(),
      const _DemoRow(
        name: 'AppSpinner',
        spec: '加载指示（自绘，非 Material）',
        demo: AppSpinner(size: 20),
      ),
      const _RowDivider(),
      Builder(
          builder: (context) => _DemoRow(
                name: 'AppToast',
                spec: '轻提示：AppToast.show(context, msg)',
                demo: ShadButton.outline(
                  onPressed: () => AppToast.show(context, '这是一条 Toast'),
                  child: const Text('试一下'),
                ),
              )),
      const _RowDivider(),
      const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppParagraph('AppParagraph：正文段落，自动换行。'),
            AppBullet('AppBullet：要点条目，圆点前缀'),
          ],
        ),
      ),
    ]);
  }
}

/// 按钮组
class _ButtonDemo extends StatelessWidget {
  const _ButtonDemo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ShadButton(
            onPressed: () {},
            leading: const Icon(LucideIcons.plus, size: 16),
            child: const Text('ShadButton'),
          ),
          ShadButton.outline(onPressed: () {}, child: const Text('outline')),
          ShadButton.destructive(
              onPressed: () {}, child: const Text('destructive')),
          ShadButton.ghost(onPressed: () {}, child: const Text('ghost')),
          ShadIconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// 表单组（Stateful：交互状态真实可玩）
class _FormDemo extends StatefulWidget {
  const _FormDemo();

  @override
  State<_FormDemo> createState() => _FormDemoState();
}

class _FormDemoState extends State<_FormDemo> {
  bool _switch = true;
  bool _check = false;
  double _slider = 33;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          const SizedBox(
            width: double.infinity,
            child: ShadInput(placeholder: Text('ShadInput 输入框')),
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            width: double.infinity,
            child: ShadTextarea(placeholder: Text('ShadTextarea 多行')),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            ShadCheckbox(
                value: _check, onChanged: (v) => setState(() => _check = v)),
            const SizedBox(width: AppSpacing.sm),
            const Text('ShadCheckbox', style: AppTypography.bodyMd),
            const Spacer(),
            const Text('ShadSwitch', style: AppTypography.bodyMd),
            const SizedBox(width: AppSpacing.sm),
            ShadSwitch(
                value: _switch, onChanged: (v) => setState(() => _switch = v)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          ShadSlider(
            initialValue: _slider,
            max: 100,
            onChanged: (v) => setState(() => _slider = v),
          ),
          Text('ShadSlider 当前值 ${_slider.round()}',
              style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

/// 展示组
class _DisplayDemo extends StatelessWidget {
  const _DisplayDemo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          ShadCard(
            width: double.infinity,
            child: Text('ShadCard 卡片容器'),
          ),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ShadBadge(child: Text('ShadBadge')),
              ShadBadge.secondary(child: Text('secondary')),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          ShadAlert(
            icon: Icon(LucideIcons.info, size: 16),
            title: Text('ShadAlert'),
            description: Text('提示信息：图标 + 标题 + 说明'),
          ),
          SizedBox(height: AppSpacing.sm),
          ShadSeparator.horizontal(),
          SizedBox(height: AppSpacing.sm),
          ShadProgress(value: 0.6),
          SizedBox(height: 2),
          Text('ShadProgress 60%', style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

/// 弹层与导航组
class _OverlayDemo extends StatelessWidget {
  const _OverlayDemo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ShadButton.outline(
            onPressed: () => showShadDialog(
              context: context,
              builder: (ctx) => ShadDialog(
                title: const Text('ShadDialog'),
                description: const Text('模态对话框示例'),
                actions: [
                  ShadButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('知道了')),
                ],
              ),
            ),
            child: const Text('Dialog'),
          ),
          ShadButton.outline(
            onPressed: () => showShadSheet(
              context: context,
              side: ShadSheetSide.bottom,
              builder: (ctx) => const ShadSheet(
                title: Text('ShadSheet'),
                description: Text('底部弹层示例'),
                child: SizedBox(height: 80),
              ),
            ),
            child: const Text('Sheet'),
          ),
          ShadTooltip(
            builder: (context) => const Text('ShadTooltip 悬停提示'),
            child: ShadButton.ghost(
                onPressed: () {}, child: const Text('Tooltip')),
          ),
        ],
      ),
    );
  }
}

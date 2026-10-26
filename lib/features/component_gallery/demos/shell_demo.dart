//! design 层九件套样张：AppScaffold/AppHeader/AppSection/AppListTile/
//! AppSettingRow/AppSpinner/AppToast/AppParagraph/AppBullet
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_list_tile.dart';
import '../../../design/widgets/app_section.dart';
import '../../../design/widgets/app_setting_row.dart';
import '../../../design/widgets/app_spinner.dart';
import '../../../design/widgets/app_toast.dart';
import '../gallery_parts.dart';

class ShellDemo extends StatelessWidget {
  const ShellDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const GalleryDemoRow(
        name: 'AppScaffold + AppHeader',
        spec: '页面壳 + 顶栏（本页就是它搭的）',
        demo: Icon(LucideIcons.layoutGrid, size: 18),
      ),
      const GalleryRowDivider(),
      const GalleryDemoRow(
        name: 'AppSection',
        spec: '内容分区：标题 + children',
        demo: Icon(LucideIcons.fileText, size: 18),
      ),
      const GalleryRowDivider(),
      const GalleryDemoRow(
        name: 'AppListTile',
        spec: '列表行：图标块 + 标题/副标题 + 尾随',
        demo: Icon(LucideIcons.menu, size: 18),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AppListTile(
          icon: LucideIcons.users,
          title: 'AppListTile 示例',
          subtitle: '设备名 · 状态说明',
          trailing: Icon(LucideIcons.chevronRight, size: 16),
        ),
      ),
      const GalleryRowDivider(),
      const GalleryDemoRow(
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
      const GalleryRowDivider(),
      const GalleryDemoRow(
        name: 'AppSpinner',
        spec: '加载指示（自绘，非 Material）',
        demo: AppSpinner(size: 20),
      ),
      const GalleryRowDivider(),
      Builder(
          builder: (context) => GalleryDemoRow(
                name: 'AppToast',
                spec: '轻提示：AppToast.show(context, msg)',
                demo: ShadButton.outline(
                  onPressed: () => AppToast.show(context, '这是一条 Toast'),
                  child: const Text('试一下'),
                ),
              )),
      const GalleryRowDivider(),
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

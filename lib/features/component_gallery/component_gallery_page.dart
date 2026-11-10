//! 组件库页：统一组件与设计规范的实时展示
//!
//! 全仓「去 material」的样板间：本页只用 flutter/widgets + shadcn_ui +
//! design 层，零 Material 引用。内容对齐 .agents/skills/shadcn-ui-flutter
//! 的组件文档；间距/圆角/颜色一律引 tokens，不硬编码。
//!
//! 结构：本文件只组装分组；共享行样式在 gallery_parts.dart，
//! 六组样张各居 demos/ 一文件——加新组件 = 加 demo 文件 + 挂一行。
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'demos/button_demo.dart';
import 'demos/variant_matrix_demo.dart';
import 'demos/display_demo.dart';
import 'demos/form_demo.dart';
import 'demos/overlay_demo.dart';
import 'demos/shell_demo.dart';
import 'demos/tokens_demo.dart';
import 'gallery_parts.dart';

class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '组件库'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          VariantMatrixDemo(),
          GalleryGroup(title: '设计 Tokens', children: [TokensDemo()]),
          GalleryGroup(title: '基础壳（design 层九件套）', children: [ShellDemo()]),
          GalleryGroup(title: '按钮', children: [ButtonDemo()]),
          GalleryGroup(title: '表单', children: [FormDemo()]),
          GalleryGroup(title: '展示', children: [DisplayDemo()]),
          GalleryGroup(title: '弹层与导航', children: [OverlayDemo()]),
        ],
      ),
    );
  }
}

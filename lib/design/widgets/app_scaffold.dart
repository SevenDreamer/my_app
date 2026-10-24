//! 页面骨架（纯 widgets 实现——去 Material 化）
//!
//! shadcn_ui 无 Scaffold，本组件是纯布局壳：背景色 + 头部 + 内容区。
//! 不依赖 Material——替代 Scaffold(appBar: AppHeader(...), body: ...) 的常用形态。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.header,
    required this.body,
    this.backgroundColor,
  });

  /// 页面头（通常为 AppHeader）
  final Widget? header;

  /// 内容区
  final Widget body;

  /// 背景色（默认中性底）
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? AppColors.surface,
      // 文字基线：脱离 Material 的纯 widgets 树里，最近的 DefaultTextStyle
      // 是 MaterialApp 的 _errorTextStyle（红字 + 黄色双下划线 + monospace），
      // 会经样式合并漏进所有文字（未设颜色的 Text 直接变红）。
      // 页面壳用字阶 bodyMd 建基线挡住，子级样式在其上合并。
      child: DefaultTextStyle(
        style: AppTypography.bodyMd,
        child: Column(
          children: [
            if (header != null) header!,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

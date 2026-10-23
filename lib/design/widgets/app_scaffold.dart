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
      child: Column(
        children: [
          if (header != null) header!,
          Expanded(child: body),
        ],
      ),
    );
  }
}

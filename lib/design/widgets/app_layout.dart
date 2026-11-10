//! 响应式布局助手（DESIGN.md · Responsive，2026-11-09）。
//!
//! 页面经 [AppLayout.of] 判断档位决定布局形态（列数/限宽/分栏）；
//! 断点值来自 [AppBreakpoints]。只影响布局形态，不影响字阶与间距。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// 视口档位（compact 手机 / medium 平板 / expanded 桌面·网页）
enum AppLayoutSize { compact, medium, expanded }

class AppLayout {
  AppLayout._(this.size);

  final AppLayoutSize size;

  bool get isCompact => size == AppLayoutSize.compact;
  bool get isMedium => size == AppLayoutSize.medium;
  bool get isExpanded => size == AppLayoutSize.expanded;

  /// 数据卡网格列数（compact 2 列，宽屏 3 列）
  int get statColumns => isCompact ? 2 : 3;

  /// 内容区最大宽度（null = 不限宽；宽档居中限宽防信息过宽）
  double? get contentMaxWidth => switch (size) {
        AppLayoutSize.compact => null,
        AppLayoutSize.medium => AppBreakpoints.contentMedium,
        AppLayoutSize.expanded => AppBreakpoints.contentExpanded,
      };

  /// 判断当前档位
  factory AppLayout.of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return AppLayout._(
      w < AppBreakpoints.compactMax
          ? AppLayoutSize.compact
          : w < AppBreakpoints.mediumMax
              ? AppLayoutSize.medium
              : AppLayoutSize.expanded,
    );
  }
}

/// 内容限宽包裹：宽档把内容约束在居中最大宽度内（compact 原样）。
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final max = AppLayout.of(context).contentMaxWidth;
    if (max == null) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}

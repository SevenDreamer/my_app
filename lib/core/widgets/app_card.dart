import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 应用卡片组件
///
/// 封装 Card 组件，默认添加阴影效果，提供统一的视觉风格
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final bool? filled;
  final Color? fillColor;

  /// 阴影强度
  final AppCardElevation elevation;

  const AppCard({
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.filled,
    this.fillColor,
    this.elevation = AppCardElevation.medium,
    super.key,
  });

  /// 低阴影（轻微浮起）
  const AppCard.low({
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.filled,
    this.fillColor,
    this.elevation = AppCardElevation.low,
    super.key,
  });

  /// 高阴影（明显浮起）
  const AppCard.high({
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.filled,
    this.fillColor,
    this.elevation = AppCardElevation.high,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: padding,
      borderRadius: borderRadius,
      borderColor: borderColor,
      borderWidth: borderWidth,
      filled: filled,
      fillColor: fillColor,
      boxShadow: _getBoxShadow(),
      child: child,
    );
  }

  List<BoxShadow> _getBoxShadow() {
    switch (elevation) {
      case AppCardElevation.none:
        return [];
      case AppCardElevation.low:
        return [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case AppCardElevation.medium:
        return [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case AppCardElevation.high:
        return [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }
}

/// 卡片阴影强度枚举
enum AppCardElevation {
  /// 无阴影
  none,
  /// 低阴影
  low,
  /// 中等阴影（默认）
  medium,
  /// 高阴影
  high,
}

//! AppProgressBar（DESIGN.md · progress-bar）：4px 细进度条。
//!
//! 轨道 border 色、填充 primary、全圆角；进度数字走 label-sm 随行（可选）。
import 'package:flutter/widgets.dart';

import '../tokens.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    this.value,
    this.caption,
  });

  /// null = 不确定进度（呼吸条）
  final double? value;

  /// 随行进度数字（如 "42%"），label-sm 规格
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: _Bar(value: value),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(caption!, style: AppTypography.labelSm),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: value == null
          ? const _IndeterminateBar()
          : DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: FractionallySizedBox(
                widthFactor: value!.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
    );
  }
}

/// 不确定进度：35% 宽滑块的循环滑动（状态过渡允许的动效）
class _IndeterminateBar extends StatefulWidget {
  const _IndeterminateBar();

  @override
  State<_IndeterminateBar> createState() => _IndeterminateBarState();
}

class _IndeterminateBarState extends State<_IndeterminateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Align(
          alignment: Alignment(-1 + 2 * _c.value, 0),
          child: FractionallySizedBox(
            widthFactor: 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

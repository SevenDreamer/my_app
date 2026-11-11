//! 组件黄金测试（golden test）——UI 的像素级安全网。
//!
//! 每件组件的代表性形态渲染后与基准图（test/goldens/）逐像素对比：
//! 改坏了视觉（颜色/圆角/字号）立刻红并产出对比图。更新基准：
//! `flutter test --update-goldens`（须设计走查后手动执行）。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:my_app/design/theme.dart';
import 'package:my_app/design/tokens.dart';
import 'package:my_app/design/widgets/app_button.dart';
import 'package:my_app/design/widgets/app_chip.dart';
import 'package:my_app/design/widgets/app_progress_bar.dart';
import 'package:my_app/design/widgets/app_stat_block.dart';

/// 统一拍图环境：固定背景/尺寸/中文字体回退
Widget _shot(Widget child) => RepaintBoundary(
      child: ShadTheme(
        data: AppTheme.shadLight,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: AppColors.neutral,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );

void main() {
  testWidgets('AppButton 四变体基线', (tester) async {
    await tester.pumpWidget(_shot(const Wrap(spacing: 8, children: [
      AppButton(label: '主要'),
      AppButton(label: '次要', variant: AppButtonVariant.outline),
      AppButton(label: '弱', variant: AppButtonVariant.ghost),
      AppButton(label: '危险', variant: AppButtonVariant.danger),
    ])));
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/app_button_variants.png'),
    );
  });

  testWidgets('AppChip 色调基线', (tester) async {
    await tester.pumpWidget(_shot(const Wrap(spacing: 8, children: [
      AppChip(label: '正常'),
      AppChip(label: '进行中', tone: AppChipTone.busy),
      AppChip(label: '异常', tone: AppChipTone.error),
      AppChip(label: '描边', variant: AppChipVariant.outline),
    ])));
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/app_chip_tones.png'),
    );
  });

  testWidgets('AppStatBlock 基线', (tester) async {
    await tester.pumpWidget(_shot(const Row(children: [
      AppStatBlock(label: '内存占用', value: '402', unit: 'MB'),
      SizedBox(width: 8),
      AppStatBlock(label: '进程', value: '2', unit: '个', size: AppStatBlockSize.sm),
    ])));
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/app_stat_block.png'),
    );
  });

  testWidgets('AppProgressBar 基线', (tester) async {
    await tester.pumpWidget(_shot(const Column(children: [
      AppProgressBar(value: 0.62, caption: '62%'),
      SizedBox(height: 8),
      AppProgressBar(caption: '进行中'),
    ])));
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('goldens/app_progress_bar.png'),
    );
  });
}

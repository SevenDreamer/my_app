//! 自动测试对话框：一键跑「启动冒烟 + 更新链自检 + DSH 运行时自检」
//!
//! 零新增 Lucide 字形（PITFALLS #27：lucide.ttf 资产变更会拦住 patch）；
//! 结果三态文字呈现（通过 / 失败 / 跳过），失败自动上报 Sentry 后明示。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_button.dart';
import '../../design/widgets/app_spinner.dart';
import 'self_test_runner.dart';

/// 弹出自动测试对话框（更新后首启 / 通知点击两个入口共用）
Future<void> showSelfTestDialog(BuildContext context) {
  return showShadDialog<void>(
    context: context,
    builder: (ctx) => const _SelfTestDialog(),
  );
}

class _SelfTestDialog extends StatefulWidget {
  const _SelfTestDialog();

  @override
  State<_SelfTestDialog> createState() => _SelfTestDialogState();
}

class _SelfTestDialogState extends State<_SelfTestDialog> {
  bool _running = false;
  String _status = '准备就绪，点击「开始测试」';
  SelfTestReport? _report;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _report = null;
    });
    final report = await SelfTestRunner.run(
      onStatus: (s) {
        if (mounted) setState(() => _status = s);
      },
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = report;
      _status = report.passed
          ? '全部通过'
          : '${report.failedCount} 项失败，已自动上报 Sentry';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return ShadDialog.alert(
      title: const Text('自动测试'),
      actions: [
        if (!_running)
          AppButton(
            onPressed: () => Navigator.of(context).pop(),
            label: '关闭',
          ),
        AppButton(
          onPressed: _running ? null : _run,
          label: _running ? '测试中…' : '开始测试',
        ),
      ],
      child: Container(
        width: 360,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_running) ...[
              const Center(child: AppSpinner(size: 24)),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(_status, style: AppTypography.labelSm),
            if (report != null) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final r in report.results) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_mark(r.outcome)} ${r.label}',
                  style: AppTypography.bodyMd,
                ),
                if (r.detail.isNotEmpty)
                  Text(r.detail, style: AppTypography.labelSm),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (!report.passed)
                const Text(
                  '失败明细已自动上报 Sentry，稍后会自动修复',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _mark(SelfTestOutcome outcome) => switch (outcome) {
        SelfTestOutcome.passed => '[通过]',
        SelfTestOutcome.failed => '[失败]',
        SelfTestOutcome.skipped => '[跳过]',
      };
}

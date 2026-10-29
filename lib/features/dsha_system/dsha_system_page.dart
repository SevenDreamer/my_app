//! DSH 系统页：安装/修复六步流程（纯 View，MVVM）
//!
//! 状态与任务编排全部来自 [DshaSystemViewModel]，本页只做渲染与交互转发。
//! 六步文案与自救语义来自 dsha_core 契约（可换排版不得改语义）。
import 'package:dsha_core/dsha_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import '../../design/widgets/app_spinner.dart';
import 'dsha_system_view_model.dart';

/// DSH 系统：离线运行时安装与修复
class DshaSystemPage extends StatefulWidget {
  const DshaSystemPage({super.key});

  @override
  State<DshaSystemPage> createState() => _DshaSystemPageState();
}

class _DshaSystemPageState extends State<DshaSystemPage> {
  late final DshaSystemViewModel _viewModel = DshaSystemViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.prepare();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 六步行图标（序号 1..6 → 语义图标）。
  static const List<IconData> _stepIcons = [
    LucideIcons.box,
    LucideIcons.wrench,
    LucideIcons.hexagon,
    LucideIcons.package,
    LucideIcons.terminal,
    LucideIcons.shieldCheck,
  ];

  IconData _stateIcon(InstallStep state) => switch (state) {
        InstallStep.ok => LucideIcons.check,
        InstallStep.failed => LucideIcons.x,
        InstallStep.running => LucideIcons.loader,
        InstallStep.skipped => LucideIcons.minus,
        InstallStep.pending => LucideIcons.circle,
      };

  Color _stateColor(InstallStep state) => switch (state) {
        InstallStep.ok => AppColors.primary,
        InstallStep.failed => AppColors.error,
        InstallStep.running => AppColors.secondary,
        InstallStep.skipped => AppColors.secondary,
        InstallStep.pending => AppColors.border,
      };

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: 'DSH 系统'),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final snapshot = _viewModel.snapshot;
          final running = _viewModel.running;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _StatusCard(viewModel: _viewModel, snapshot: snapshot),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      onPressed: !running && !_viewModel.preparing
                          ? () => _viewModel.start(
                              repair: false, selected: 0)
                          : null,
                      child: const Text('开始检查'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: !running && !_viewModel.preparing
                          ? () => _viewModel.start(
                              repair: true, selected: 0)
                          : null,
                      child: const Text('修复并检查'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ShadButton.outline(
                    onPressed: running && !snapshot.cancelRequested
                        ? _viewModel.cancel
                        : null,
                    child: const Text('取消'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ShadCard(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('检查步骤', style: AppTypography.labelSm),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < InstallTask.names.length; i++)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          children: [
                            Icon(_stepIcons[i],
                                size: 18, color: AppColors.secondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${i + 1}. ${InstallTask.names[i]}',
                                style: AppTypography.bodyMd,
                              ),
                            ),
                            Icon(
                              _stateIcon(snapshot.steps[i]),
                              size: 16,
                              color: _stateColor(snapshot.steps[i]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ShadCard(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('详细输出', style: AppTypography.labelSm),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      height: 160,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.neutral,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          snapshot.log.isEmpty ? '（暂无输出）' : snapshot.log,
                          style: AppTypography.labelSm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 状态卡：环境就绪 + 当前阶段 + 结局摘要。
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.viewModel, required this.snapshot});

  final DshaSystemViewModel viewModel;
  final InstallSnapshot snapshot;

  String get _statusText {
    if (viewModel.preparing) return '正在准备环境…';
    if (snapshot.outcome == InstallOutcome.running) return snapshot.phase;
    if (snapshot.failure.isNotEmpty) return snapshot.failure;
    return viewModel.ready ? '环境已就绪' : '环境未就绪（未安装离线运行时）';
  }

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (viewModel.preparing || snapshot.outcome == InstallOutcome.running)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: AppSpinner(),
            )
          else
            Icon(
              viewModel.ready ? LucideIcons.check : LucideIcons.alertCircle,
              size: 20,
              color: viewModel.ready ? AppColors.primary : AppColors.error,
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusText, style: AppTypography.bodyMd),
                Text(
                  '解包引擎：${viewModel.extractorName}',
                  style: AppTypography.labelSm,
                ),
                if (snapshot.outcome != InstallOutcome.idle)
                  Text(
                    '耗时 ${snapshot.elapsedSeconds}s',
                    style: AppTypography.labelSm,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

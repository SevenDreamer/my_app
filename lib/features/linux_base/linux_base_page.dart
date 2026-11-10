//! Linux 底座域页面（P0 + 管理闭环）：系统仪表盘 / 操作 / 快照管理。
//!
//! MVVM 铁律：只读 [LinuxBaseViewModel] 快照 + 调命令方法，不直连服务。
//! 视觉照 DESIGN.md 仪表盘规格（2026-11-09 登记）：stat-block / status-badge /
//! progress-bar / action-row——页面零硬编码色值，全部走 tokens。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_layout.dart';
import '../dsh_go/dsh_go_host.dart';
import 'linux_base_view_model.dart';
import '../../data/services/linux_base_service.dart';

class LinuxBasePage extends StatefulWidget {
  const LinuxBasePage({super.key});

  @override
  State<LinuxBasePage> createState() => _LinuxBasePageState();
}

class _LinuxBasePageState extends State<LinuxBasePage> {
  late final LinuxBaseViewModel _vm = LinuxBaseViewModel(LinuxBaseService());

  @override
  void initState() {
    super.initState();
    _vm.refresh();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Linux 底座'),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final stats = _vm.stats;
          final rootfsMb =
              ((stats['rootfsBytes'] as num?)?.toInt() ?? 0) / (1024 * 1024);
          final memTotal = (stats['memTotalMb'] as num?)?.toInt() ?? 0;
          final memAvail = (stats['memAvailableMb'] as num?)?.toInt() ?? 0;
          final processes = (stats['processes'] as List?) ?? const [];
          return AppContentWidth(
            child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _statusHero(),
              const SizedBox(height: AppSpacing.lg),
              _statGrid(
                rootfsMb: rootfsMb,
                memUsed: memTotal - memAvail,
                processes: processes.length,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_vm.installing) ...[
                _installingBlock(),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (!_vm.installing &&
                  (_vm.phase == 'notInstalled' || _vm.phase == 'error'))
                ...[_installPrompt(), const SizedBox(height: AppSpacing.lg)],
              _actionRow(),
              if (_vm.message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_vm.message!, style: AppTypography.labelSm),
              ],
              const SizedBox(height: AppSpacing.lg),
              _snapshotSection(),
            ],
          ),
          );
        },
      ),
    );
  }

  /// 状态 Hero：status-badge + 版本/时长（DESIGN.md · status-badge）
  Widget _statusHero() {
    return Row(
      children: [
        _StatusBadge(phase: _vm.phase),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vm.runtimeVersion == null
                    ? '系统未就绪'
                    : 'Ubuntu · ${_vm.runtimeVersion}',
                style: AppTypography.bodyMd,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '运行时长 ${_durationLabel((_vm.stats['prootUptimeSec'] as num?)?.toInt())}',
                style: AppTypography.labelSm,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// stat 网格（DESIGN.md · stat-block + Responsive）：compact 2 列，宽屏 3 列
  Widget _statGrid({
    required double rootfsMb,
    required int memUsed,
    required int processes,
  }) {
    final layout = AppLayout.of(context);
    final cards = [
      _StatBlock(label: '内存占用', value: '$memUsed', unit: 'MB'),
      _StatBlock(
          label: '系统占用', value: rootfsMb.toStringAsFixed(0), unit: 'MB'),
      _StatBlock(label: '底座进程', value: '$processes', unit: '个'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = layout.statColumns;
        final w =
            (constraints.maxWidth - AppSpacing.md * (cols - 1)) / cols;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final c in cards) SizedBox(width: w, child: c),
          ],
        );
      },
    );
  }

  /// 安装进度（DESIGN.md · progress-bar）
  Widget _installingBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _StatusBadge(phase: 'installing'),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '安装中：${_vm.installProgress?.step ?? '准备'}',
              style: AppTypography.bodyMd,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: LinearProgressIndicator(
            value: _vm.installProgress?.ratio,
            minHeight: 4,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
        ),
        if (_vm.installProgress != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${(_vm.installProgress!.ratio * 100).toStringAsFixed(0)}%',
              style: AppTypography.labelSm,
            ),
          ),
      ],
    );
  }

  /// 未安装引导卡
  Widget _installPrompt() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('创建底座系统',
              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text('从镜像仓下载 Ubuntu rootfs 解包（约几分钟，占 800 MB）',
              style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.md),
          ShadButton(
            onPressed: _vm.busy ? null : _vm.installSystem,
            child: const Text('安装系统'),
          ),
        ],
      ),
    );
  }

  /// 操作排（DESIGN.md · action-row）：主按钮唯一，危险操作 ghost 红字
  Widget _actionRow() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ShadButton(
          onPressed: _vm.busy ? null : _vm.startSystem,
          child: const Text('启动系统'),
        ),
        ShadButton.outline(
          onPressed: _vm.busy ? null : _vm.stopSystem,
          child: const Text('停止'),
        ),
        ShadButton.outline(
          onPressed: _vm.busy ? null : _vm.reinstallSystem,
          child: const Text('重新安装'),
        ),
        ShadButton.ghost(
          onPressed: _vm.busy ? null : _confirmReset,
          child: const Text('重置系统', style: TextStyle(color: AppColors.error)),
        ),
        ShadButton.ghost(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DshGoHost()),
          ),
          child: const Text('终端'),
        ),
      ],
    );
  }

  /// 快照区（卡片行）
  Widget _snapshotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('快照',
                  style:
                      AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            ),
            Text('保留最近 3 个', style: AppTypography.labelSm),
            const SizedBox(width: AppSpacing.sm),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed:
                  _vm.busy ? null : () => _vm.createSnapshot(note: '手动快照'),
              child: const Text('创建快照'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_vm.snapshots.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('暂无快照——改系统前先打一个，坏了可一键回滚',
                style: AppTypography.labelSm),
          ),
        for (final snap in _vm.snapshots)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snap.name, style: AppTypography.bodyMd),
                      Text(
                        '${_timeLabel(snap.createdAt)} · ${_bytesLabel(snap.bytes)}'
                        '${snap.note == null ? '' : ' · ${snap.note}'}',
                        style: AppTypography.labelSm,
                      ),
                    ],
                  ),
                ),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: _vm.busy ? null : () => _vm.restoreSnapshot(snap),
                  child: const Text('回滚'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: _vm.busy ? null : () => _vm.deleteSnapshot(snap),
                  child:
                      const Text('删除', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置系统'),
        content: const Text('将清空系统回到未安装态。快照会保留，可回滚或重新安装。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重置', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) await _vm.resetSystem();
  }

  String _durationLabel(int? sec) {
    if (sec == null) return '未运行';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return h > 0 ? '${h}小时 $m 分' : '$m 分';
  }

  String _bytesLabel(int bytes) {
    if (bytes < 0) return '—';
    final mb = bytes / (1024 * 1024);
    return mb >= 1024
        ? '${(mb / 1024).toStringAsFixed(2)} GB'
        : '${mb.toStringAsFixed(0)} MB';
  }

  String _timeLabel(DateTime t) =>
      '${t.month}-${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}

/// stat 数据卡（DESIGN.md · stat-block）：display 大数字 + label-sm 标签
class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.display),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(unit!, style: AppTypography.labelSm),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

/// 状态徽章（DESIGN.md · status-badge）：胶囊 + 6px 圆点，不引入新色相
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.phase});

  final String phase;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (phase) {
      'running' => (
          '运行中',
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.10)
        ),
      'installing' || 'starting' || 'stopping' => (
          '进行中',
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.10)
        ),
      'error' => (
          '异常',
          AppColors.error,
          AppColors.error.withValues(alpha: 0.12)
        ),
      'installed' => (
          '已安装',
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.10)
        ),
      _ => (
          '未安装',
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.10)
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.labelSm.copyWith(color: fg)),
        ],
      ),
    );
  }
}

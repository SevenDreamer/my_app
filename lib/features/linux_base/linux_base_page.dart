//! Linux 底座域页面（P0）：系统总览 / 操作 / 快照管理。
//!
//! MVVM 铁律：只读 [LinuxBaseViewModel] 快照 + 调命令方法，不直连服务。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_list_tile.dart';
import '../../design/widgets/app_section.dart';
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
          final rootfsMb = ((stats['rootfsBytes'] as num?)?.toInt() ?? 0) / (1024 * 1024);
          final memTotal = (stats['memTotalMb'] as num?)?.toInt() ?? 0;
          final memAvail = (stats['memAvailableMb'] as num?)?.toInt() ?? 0;
          final processes = (stats['processes'] as List?) ?? const [];
          final uptime = (stats['prootUptimeSec'] as num?)?.toInt();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_vm.message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(_vm.message!, style: AppTypography.bodyMd),
                ),
              // 未安装/异常态：安装引导卡（P0「安装重建」入口，2026-11-09 补）
              if (!_vm.installing &&
                  (_vm.phase == 'notInstalled' || _vm.phase == 'error'))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppSection(
                    title: '创建底座系统',
                    children: [
                      AppListTile(
                        icon: LucideIcons.download,
                        title: _vm.phase == 'error' ? '重新安装系统' : '安装系统',
                        subtitle: '从内置镜像解包 Ubuntu rootfs（约几分钟，占 800 MB）',
                        onTap: _vm.busy ? null : _vm.installSystem,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              if (_vm.installing)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '安装中：${_vm.installProgress?.step ?? '准备'}…',
                        style: AppTypography.bodyMd,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LinearProgressIndicator(
                        value: _vm.installProgress?.ratio,
                      ),
                    ],
                  ),
                ),
              AppSection(
                title: '系统状态',
                trailing: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: _vm.refresh,
                  child: const Text('刷新'),
                ),
                children: [
                  AppListTile(
                    icon: LucideIcons.activity,
                    title: '运行状态',
                    subtitle: _phaseLabel(_vm.phase),
                  ),
                  AppListTile(
                    icon: LucideIcons.package,
                    title: '版本',
                    subtitle: [
                      if (_vm.runtimeVersion != null) '系统 ${_vm.runtimeVersion}',
                      if (_vm.installedVersion != null) 'DSH ${_vm.installedVersion}',
                    ].join(' · '),
                  ),
                  AppListTile(
                    icon: LucideIcons.gauge,
                    title: '负载 / 内存',
                    subtitle:
                        'load ${stats['load1'] ?? '—'} · 内存可用 ${memTotal - memAvail}/$memTotal MB',
                  ),
                  AppListTile(
                    icon: LucideIcons.hardDrive,
                    title: '系统占用',
                    subtitle: 'rootfs ${rootfsMb.toStringAsFixed(0)} MB',
                  ),
                  AppListTile(
                    icon: LucideIcons.clock,
                    title: '运行时长 / 进程',
                    subtitle:
                        '${_durationLabel(uptime)} · ${processes.length} 个底座进程',
                  ),
                ],
              ),
              AppSection(
                title: '操作',
                trailing: _vm.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                children: [
                  AppListTile(
                    icon: LucideIcons.play,
                    title: '启动系统',
                    subtitle: '唤起底座引擎（与 DSH 壳共用）',
                    onTap: _vm.busy ? null : _vm.startSystem,
                  ),
                  AppListTile(
                    icon: LucideIcons.square,
                    title: '停止系统',
                    subtitle: '回滚前/省电时停止',
                    onTap: _vm.busy ? null : _vm.stopSystem,
                  ),
                  AppListTile(
                    icon: LucideIcons.download,
                    title: '重新安装系统',
                    subtitle: '清掉重装（下载镜像解包，约几分钟）',
                    onTap: _vm.busy ? null : _vm.reinstallSystem,
                  ),
                  AppListTile(
                    icon: LucideIcons.trash2,
                    title: '重置系统',
                    subtitle: '清空系统回未安装态（快照保留，可回滚）',
                    onTap: _vm.busy ? null : _vm.resetSystem,
                  ),
                  AppListTile(
                    icon: LucideIcons.terminal,
                    title: '打开终端',
                    subtitle: '在 DSH 会话中进终端（引擎就绪后可用）',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DshGoHost()),
                    ),
                  ),
                ],
              ),
              if (_vm.progress != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: LinearProgressIndicator(value: _vm.progress!.ratio),
                ),
              AppSection(
                title: '快照（保留最近 3 个）',
                trailing: ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: _vm.busy
                      ? null
                      : () => _vm.createSnapshot(note: '手动快照'),
                  child: const Text('创建快照'),
                ),
                children: [
                  if (_vm.snapshots.isEmpty)
                    const AppListTile(
                      icon: LucideIcons.archive,
                      title: '暂无快照',
                      subtitle: '改系统前先打快照，坏了可一键回滚',
                      showDivider: false,
                    ),
                  for (final snap in _vm.snapshots)
                    AppListTile(
                      icon: LucideIcons.archive,
                      title: snap.name,
                      subtitle:
                          '${_timeLabel(snap.createdAt)} · ${_bytesLabel(snap.bytes)}'
                          '${snap.note == null ? '' : ' · ${snap.note}'}',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: _vm.busy
                                ? null
                                : () => _vm.restoreSnapshot(snap),
                            child: const Text('回滚'),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed:
                                _vm.busy ? null : () => _vm.deleteSnapshot(snap),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _phaseLabel(String phase) => switch (phase) {
        'notInstalled' => '未安装（可安装）',
        'installed' => '已安装（未运行）',
        'starting' => '启动中',
        'running' => '运行中',
        'stopping' => '停止中',
        'error' => '异常',
        _ => phase,
      };

  String _durationLabel(int? sec) {
    if (sec == null) return '未运行';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return h > 0 ? '${h}小时 $m 分' : '$m 分';
  }

  String _bytesLabel(int bytes) {
    if (bytes < 0) return '—';
    final mb = bytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(2)} GB' : '${mb.toStringAsFixed(0)} MB';
  }

  String _timeLabel(DateTime t) =>
      '${t.month}-${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}

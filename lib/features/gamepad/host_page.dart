//! 被控端页：搜索附近手柄、列表展示、点选配对
//!
//! MVVM：只读 HostViewModel 快照 + 调命令方法，不触碰链路层。
//! 流程：让控制端点「启动广播」→ 本页搜索 → 列表出现 my_app Gamepad →
//! 点击配对（系统弹确认框）→ 回到游戏即可收到手柄输入。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'host_view_model.dart';

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  late final HostViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = HostViewModel();
    // 蓝牙能力仅 Android 有实现，其他平台只展示说明
    if (defaultTargetPlatform == TargetPlatform.android) _vm.refresh();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return AppScaffold(
      header: const AppHeader(title: '被控端'),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '让控制端点「启动广播」，然后在下方搜索列表里选择手柄配对。'
                  '配对成功后手柄输入直接进入系统游戏。',
                  style: TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!isAndroid) ...[
                  const Text(
                    '被控端搜索/配对仅 Android 支持（Windows 主机端在后续里程碑落地）。',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                ] else ...[
                  Row(
                    children: [
                      _ActionButton(
                        label: _vm.scanning ? '停止搜索' : '搜索手柄',
                        primary: !_vm.scanning,
                        onTap: () => _vm.scanning
                            ? _vm.stopScan()
                            : _vm.startScan(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _ActionButton(
                        label: '打开蓝牙设置',
                        onTap: _vm.openBluetoothSettings,
                      ),
                    ],
                  ),
                  if (_vm.error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '出错：${_vm.error}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_vm.paired.isNotEmpty) ...[
                    const _SectionTitle('已配对'),
                    for (final d in _vm.paired)
                      _DeviceRow(
                        name: d.name.isEmpty ? '（未知设备）' : d.name,
                        address: d.address,
                        trailing: const Text(
                          '✓ 已配对',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondary),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const _SectionTitle('附近设备'),
                  if (_vm.found.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(
                        '（未发现设备——点「搜索手柄」开始）',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.secondary),
                      ),
                    ),
                  for (final d in _vm.found)
                    _DeviceRow(
                      name: d.name.isEmpty ? '（未知设备）' : d.name,
                      address: d.address,
                      badge: d.isGamepad ? '手柄' : null,
                      trailing: Text(
                        d.paired
                            ? '✓ 已配对'
                            : d.bonding
                                ? '配对中…'
                                : '点击配对',
                        style: TextStyle(
                          fontSize: 12,
                          color: d.paired || d.bonding
                              ? AppColors.secondary
                              : AppColors.primary,
                          fontWeight: d.paired || d.bonding
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                      onTap: (d.paired || d.bonding)
                          ? null
                          : () => _vm.pair(d.address),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    this.primary = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primary ? AppColors.primary : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

/// 设备行：名称 + 地址 + 右侧状态（可点按配对）
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.name,
    required this.address,
    required this.trailing,
    this.badge,
    this.onTap,
  });

  final String name;
  final String address;
  final Widget trailing;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    address,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

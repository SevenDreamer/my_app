//! 被控端 · 设备连接页：搜索附近手柄、列表展示、点选配对
//!
//! MVVM：只读共享的 HostViewModel 快照 + 调命令方法，不触碰链路层。
//! 焦点捕获与被控端页同款——手柄按键记进输入日志、不抢焦点。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'host_view_model.dart';
import 'host_widgets.dart';

class HostConnectionPage extends StatefulWidget {
  const HostConnectionPage({super.key, required this.vm});

  /// 与被控端页共享的 VM（输入日志/连接状态一份真相）
  final HostViewModel vm;

  @override
  State<HostConnectionPage> createState() => _HostConnectionPageState();
}

class _HostConnectionPageState extends State<HostConnectionPage> {
  final _focusNode = FocusNode(debugLabel: 'host-conn-input-capture');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 捕获手柄输入：记日志 + 全部消费（不让系统拿去移动焦点）
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyUpEvent) {
      widget.vm.logKey(event.logicalKey, down: event is KeyDownEvent);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '设备连接'),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: widget.vm,
          builder: (context, _) {
            final vm = widget.vm;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '让控制端点「启动广播」，然后在「附近设备」里选择手柄配对。'
                    '配对成功后手柄输入直接进入系统游戏。',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _ActionButton(
                        label: vm.scanning ? '停止搜索' : '搜索手柄',
                        primary: !vm.scanning,
                        onTap: () =>
                            vm.scanning ? vm.stopScan() : vm.startScan(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _ActionButton(
                        label: '打开蓝牙设置',
                        onTap: vm.openBluetoothSettings,
                      ),
                    ],
                  ),
                  if (vm.error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '出错：${vm.error}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  HostCard(
                    title: '已连接',
                    children: [
                      if (vm.connected.isEmpty)
                        const HostHint('（暂无已连接设备——配对后手柄自动连接）')
                      else
                        for (final d in vm.connected)
                          _DeviceRow(
                            name: d.name.isEmpty ? '（未知设备）' : d.name,
                            address: d.address,
                            divider: d != vm.connected.last,
                            trailing: const Text(
                              '✓ 已连接',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                            ),
                          ),
                    ],
                  ),
                  HostCard(
                    title: '已配对',
                    children: [
                      if (vm.paired.isEmpty)
                        const HostHint('（暂无已配对设备）')
                      else
                        for (final d in vm.paired)
                          _DeviceRow(
                            name: d.name.isEmpty ? '（未知设备）' : d.name,
                            address: d.address,
                            divider: d != vm.paired.last,
                            trailing: const Text(
                              '✓ 已配对',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                            ),
                          ),
                    ],
                  ),
                  HostCard(
                    title: '附近设备',
                    children: [
                      if (vm.found.isEmpty)
                        const HostHint('（未发现设备——点「搜索手柄」开始）')
                      else
                        for (final d in vm.found)
                          _DeviceRow(
                            name: d.name.isEmpty ? '（未知设备）' : d.name,
                            address: d.address,
                            badge: d.isGamepad ? '手柄' : null,
                            divider: d != vm.found.last,
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
                                : () => vm.pair(d.address),
                          ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
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
    this.divider = true,
    this.onTap,
  });

  final String name;
  final String address;
  final Widget trailing;
  final String? badge;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: AppColors.border))
              : null,
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
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

//! 被控端页：三个卡片（已连接 / 已配对 / 附近设备）+ 输入日志
//!
//! MVVM：只读 HostViewModel 快照 + 调命令方法，不触碰链路层。
//! 页面顶部 Focus 捕获手柄按键——既实时记进「输入日志」，
//! 又消费掉 key 事件防止方向键/确认键把焦点抢到返回键上。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final _focusNode = FocusNode(debugLabel: 'host-input-capture');

  @override
  void initState() {
    super.initState();
    _vm = HostViewModel();
    // 蓝牙能力仅 Android 有实现，其他平台只展示说明
    if (defaultTargetPlatform == TargetPlatform.android) _vm.refresh();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// 捕获手柄输入：记日志 + 全部消费（不让系统拿去移动焦点）
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final name =
          event.logicalKey.debugName ?? 'Key(${event.logicalKey.keyId})';
      final now = DateTime.now();
      String p(int v) => v.toString().padLeft(2, '0');
      _vm.logInput('${p(now.hour)}:${p(now.minute)}:${p(now.second)}  $name');
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return AppScaffold(
      header: const AppHeader(title: '被控端'),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
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
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _Card(
                      title: '已连接',
                      children: [
                        if (_vm.connected.isEmpty)
                          const _Hint('（暂无已连接设备——配对后手柄自动连接）')
                        else
                          for (final d in _vm.connected)
                            _DeviceRow(
                              name: d.name.isEmpty ? '（未知设备）' : d.name,
                              address: d.address,
                              divider: d != _vm.connected.last,
                              trailing: const Text(
                                '✓ 已连接',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.secondary),
                              ),
                            ),
                      ],
                    ),
                    _Card(
                      title: '已配对',
                      children: [
                        if (_vm.paired.isEmpty)
                          const _Hint('（暂无已配对设备）')
                        else
                          for (final d in _vm.paired)
                            _DeviceRow(
                              name: d.name.isEmpty ? '（未知设备）' : d.name,
                              address: d.address,
                              divider: d != _vm.paired.last,
                              trailing: const Text(
                                '✓ 已配对',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.secondary),
                              ),
                            ),
                      ],
                    ),
                    _Card(
                      title: '附近设备',
                      children: [
                        if (_vm.found.isEmpty)
                          const _Hint('（未发现设备——点「搜索手柄」开始）')
                        else
                          for (final d in _vm.found)
                            _DeviceRow(
                              name: d.name.isEmpty ? '（未知设备）' : d.name,
                              address: d.address,
                              badge: d.isGamepad ? '手柄' : null,
                              divider: d != _vm.found.last,
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
                    ),
                  ],
                  _Card(
                    title: '输入日志',
                    children: [
                      if (_vm.inputLog.isEmpty)
                        const _Hint('（按下手柄按键，这里实时显示收到的输入）')
                      else
                        for (final line in _vm.inputLog)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              line,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                            ),
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

/// 卡片容器：标题 + 内容列表
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.secondary),
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

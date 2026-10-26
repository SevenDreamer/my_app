//! 设备互联页：两台手机互联的真实界面（里程碑① 连接最小闭环）
//!
//! MVVM：View 只读 ViewModel 快照 + 调命令方法，不触碰传输层。
//! 双角色同一入口：本机建组（Host）或扫描加入（Client），文本双向互通。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/models/link_message.dart';
import '../../data/models/link_peer.dart';
import '../../data/services/link_transport.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_section.dart';
import 'device_link_view_model.dart';
import 'gamepad/gamepad_page.dart';

class DeviceLinkPage extends StatefulWidget {
  const DeviceLinkPage({super.key});

  @override
  State<DeviceLinkPage> createState() => _DeviceLinkPageState();
}

class _DeviceLinkPageState extends State<DeviceLinkPage> {
  late final DeviceLinkViewModel _vm;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = DeviceLinkViewModel();
  }

  @override
  void dispose() {
    _input.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: '设备互联'),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _StatusBanner(status: _vm.status, error: _vm.error),
                    const SizedBox(height: AppSpacing.md),
                    AppSection(
                      title: '本机角色',
                      children: [
                        _RoleActions(vm: _vm),
                        if (_vm.groupInfo != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _GroupInfo(info: _vm.groupInfo!),
                        ],
                      ],
                    ),
                    if (_vm.role == LinkRole.client) ...[
                      AppSection(
                        title: '附近设备',
                        children: [
                          if (_vm.peers.isEmpty)
                            const AppParagraph('扫描中暂未发现设备——'
                                '请确认对端已点「建组」，两台设备靠近一些。')
                          else
                            for (final p in _vm.peers)
                              _PeerTile(peer: p, vm: _vm),
                        ],
                      ),
                    ],
                    AppSection(
                      title: '消息互通',
                      children: [
                        if (_vm.messages.isEmpty)
                          const AppParagraph('连接后在这里收发消息。')
                        else
                          for (final m in _vm.messages.reversed)
                            _MessageLine(message: m),
                      ],
                    ),
                    AppSection(
                      title: '外设模拟',
                      children: [
                        ShadButton.outline(
                          onPressed: () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, __, ___) => const GamepadPage(),
                              transitionsBuilder: (_, animation, __, child) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                            ),
                          ),
                          child: const Text('手柄调试台'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _InputBar(controller: _input, vm: _vm),
            ],
          );
        },
      ),
    );
  }
}

/// 顶部状态横幅：连接状态 + 错误提示
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, this.error});

  final LinkStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = error ??
        switch (status) {
          LinkStatus.idle => '未连接 · 选一个角色开始互联',
          LinkStatus.working => '进行中…',
          LinkStatus.connected => '已连接',
          LinkStatus.error => '出错了',
        };
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(LucideIcons.wrench, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色操作：建组 / 扫描（互斥两按钮）+ 撤销
class _RoleActions extends StatelessWidget {
  const _RoleActions({required this.vm});

  final DeviceLinkViewModel vm;

  @override
  Widget build(BuildContext context) {
    final isHost = vm.role == LinkRole.host;
    final isClient = vm.role == LinkRole.client;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ShadButton(
          enabled: !vm.busy && !isClient,
          leading: const Icon(LucideIcons.network, size: 16),
          onPressed: () async {
            if (!await vm.ensurePermissions()) return;
            await vm.createGroup();
          },
          child: Text(isHost ? '已建组' : '建组（Host）'),
        ),
        ShadButton(
          enabled: !vm.busy && !isHost,
          leading: const Icon(LucideIcons.search, size: 16),
          onPressed: () async {
            if (!await vm.ensurePermissions()) return;
            await vm.startScan();
          },
          child: const Text('扫描设备'),
        ),
        if (isHost || isClient)
          ShadButton.outline(
            enabled: !vm.busy,
            leading: const Icon(LucideIcons.trash2, size: 16),
            onPressed: () async {
              if (isHost) {
                await vm.removeGroup();
              } else {
                await vm.disconnect();
              }
            },
            child: Text(isHost ? '解散' : '断开'),
          ),
      ],
    );
  }
}

/// 建组信息：SSID / PSK / IP（对端凭此加入）
class _GroupInfo extends StatelessWidget {
  const _GroupInfo({required this.info});

  final ({String ssid, String psk, String ip}) info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.neutral,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        'SSID: ${info.ssid}\nPSK: ${info.psk}\nIP: ${info.ip}',
        style:
            const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
      ),
    );
  }
}

/// 单个发现设备行：点击连接
class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer, required this.vm});

  final LinkPeer peer;
  final DeviceLinkViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(LucideIcons.users, size: 18),
      title: Text(peer.name),
      subtitle: Text(
        peer.address,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: ShadButton.outline(
        enabled: !vm.busy,
        onPressed: () => vm.connect(peer),
        child: const Text('连接'),
      ),
    );
  }
}

/// 单条消息（倒序展示：最新在上）
class _MessageLine extends StatelessWidget {
  const _MessageLine({required this.message});

  final LinkMessage message;

  @override
  Widget build(BuildContext context) {
    final label = message.fromSelf ? '我' : '对端';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        '$label: ${message.text}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: message.fromSelf ? AppColors.primary : null,
            ),
      ),
    );
  }
}

/// 底部输入栏：文本框 + 发送
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.vm});

  final TextEditingController controller;
  final DeviceLinkViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: ShadInput(
                controller: controller,
                placeholder: const Text('输入消息'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ShadIconButton(
              enabled: !vm.busy,
              icon: const Icon(LucideIcons.zap, size: 18),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    await vm.sendText(controller.text);
    controller.clear();
  }
}

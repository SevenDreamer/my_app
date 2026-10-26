//! 被控端页：「设备连接」入口 + 输入日志
//!
//! MVVM：持有共享 HostViewModel（设备连接页复用同一实例），只读快照 +
//! 调命令方法。Focus 捕获手柄按键——既实时记进「输入日志」，
//! 又消费掉 key 事件防止方向键/确认键把焦点抢到返回键上。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'host_connection_page.dart';
import 'host_view_model.dart';
import 'host_widgets.dart';

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
    if (event is KeyDownEvent || event is KeyUpEvent) {
      _vm.logKey(event.logicalKey, down: event is KeyDownEvent);
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
                    '本机作为被控端接收手柄操作。连接管理在「设备连接」，'
                    '收到的手柄输入实时记录在下方日志。',
                    style: TextStyle(fontSize: 12, color: AppColors.secondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!isAndroid) ...[
                    const Text(
                      '被控端搜索/配对仅 Android 支持（Windows 主机端在后续里程碑落地）。',
                      style: TextStyle(fontSize: 12, color: AppColors.secondary),
                    ),
                  ] else ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (_, __, ___) =>
                              HostConnectionPage(vm: _vm),
                          transitionsBuilder: (_, animation, __, child) =>
                              FadeTransition(opacity: animation, child: child),
                        ),
                      ),
                      child: Container(
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
                            const Text(
                              '设备连接',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '已连接 ${_vm.connected.length} 台 · '
                              '已配对 ${_vm.paired.length} 台',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  HostCard(
                    title: '延迟测试',
                    children: [
                      const HostHint(
                          '与控制端连同一 Wi-Fi，然后开始测量（测量时勿触碰控制端屏幕）。'),
                      const SizedBox(height: AppSpacing.sm),
                      HostActionButton(
                        label: _vm.latencyTesting ? '停止测量' : '开始测量',
                        primary: !_vm.latencyTesting,
                        onTap: () => _vm.setLatencyTest(!_vm.latencyTesting),
                      ),
                      if (_vm.latencyStats != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        HostHint(_vm.latencyStats!),
                      ],
                    ],
                  ),
                  HostCard(
                    title: '输入日志',
                    children: [
                      if (_vm.intervalStats != null) ...[
                        HostHint(_vm.intervalStats!),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      if (_vm.inputLog.isEmpty)
                        const HostHint('（按下手柄按键，这里实时显示收到的输入）')
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

//! 控制端页：手机模拟手柄（虚拟摇杆/ABXY/十字键）+ 报告回显
//!
//! MVVM：只读 GamepadViewModel 快照 + 调命令方法，不触碰链路层。
//! 不自动连接——用户点「启动」才注册 HID 广播。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'fake_gamepad_link.dart';
import 'gamepad_link.dart';
import 'gamepad_report.dart';
import 'gamepad_view_model.dart';
import 'hid_gamepad_link.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  late final GamepadLink _link;
  late final GamepadViewModel _vm;
  GamepadLinkState? _prev;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    // Android 走真 HID；其它平台（桌面调试）退回假链路
    _link = defaultTargetPlatform == TargetPlatform.android
        ? HidGamepadLink()
        : FakeGamepadLink();
    _vm = GamepadViewModel(_link);
    _prev = _vm.state;
    _vm.addListener(_onVmTick);
  }

  /// 连接建立 / 真实断开时弹框提示
  void _onVmTick() {
    final s = _vm.state;
    if (!_dialogVisible) {
      if (_prev == GamepadLinkState.connected &&
          s == GamepadLinkState.disconnected) {
        _showDialog(
          title: '设备已断开',
          body: '与被控端的连接已断开，可以点「启动广播」重新配对。',
          confirmLabel: '重新连接',
          onConfirm: () => _vm.connect(),
        );
      } else if (_prev != GamepadLinkState.connected &&
          s == GamepadLinkState.connected) {
        _showDialog(
          title: '设备已连接',
          body: '与被控端（主机）连接成功，可以开始操作了。',
        );
      }
    }
    _prev = s;
  }

  /// 通用提示弹框（可选确认键）
  void _showDialog({
    required String title,
    required String body,
    String? confirmLabel,
    VoidCallback? onConfirm,
  }) {
    _dialogVisible = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      pageBuilder: (dialogContext, _, __) => Center(
        child: Container(
          width: 280,
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.neutral,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '知道了',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.secondary),
                      ),
                    ),
                  ),
                  if (confirmLabel != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        onConfirm?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ).whenComplete(() => _dialogVisible = false);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmTick);
    _vm.dispose(); // 内部会 stop() 链路并释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '控制端'),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final r = _vm.report;
          return Column(
            children: [
              _StatusBar(vm: _vm),
              _LatencyBar(vm: _vm),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      // 肩键/功能键行
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PadButton(
                            label: 'L1',
                            pressed: r.pressed(GamepadButton.l1),
                            onDown: () => _vm.setButton(GamepadButton.l1, true),
                            onUp: () => _vm.setButton(GamepadButton.l1, false),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _PadButton(
                            label: 'Back',
                            wide: true,
                            pressed: r.pressed(GamepadButton.back),
                            onDown: () =>
                                _vm.setButton(GamepadButton.back, true),
                            onUp: () =>
                                _vm.setButton(GamepadButton.back, false),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _PadButton(
                            label: 'Start',
                            wide: true,
                            pressed: r.pressed(GamepadButton.start),
                            onDown: () =>
                                _vm.setButton(GamepadButton.start, true),
                            onUp: () =>
                                _vm.setButton(GamepadButton.start, false),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          _PadButton(
                            label: 'R1',
                            pressed: r.pressed(GamepadButton.r1),
                            onDown: () => _vm.setButton(GamepadButton.r1, true),
                            onUp: () => _vm.setButton(GamepadButton.r1, false),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // 左：摇杆 + 十字键；右：ABXY + 摇杆
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              _Stick(
                                lx: r.lx.toDouble(),
                                ly: r.ly.toDouble(),
                                onMove: (dx, dy) =>
                                    _vm.moveStick(left: true, dx: dx, dy: dy),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _Dpad(hat: r.dpad, vm: _vm),
                            ],
                          ),
                          Column(
                            children: [
                              _AbxyCluster(vm: _vm, report: r),
                              const SizedBox(height: AppSpacing.md),
                              _Stick(
                                lx: r.rx.toDouble(),
                                ly: r.ry.toDouble(),
                                onMove: (dx, dy) =>
                                    _vm.moveStick(left: false, dx: dx, dy: dy),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _Readout(vm: _vm),
            ],
          );
        },
      ),
    );
  }
}

/// 顶栏：启动/停止按钮 + 链路状态 + 已发帧数
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.vm});

  final GamepadViewModel vm;

  @override
  Widget build(BuildContext context) {
    const label = {
      GamepadLinkState.idle: '未启动',
      GamepadLinkState.advertising: '广播中',
      GamepadLinkState.connected: '已连接',
      GamepadLinkState.disconnected: '已断开',
    };
    final running = vm.state == GamepadLinkState.advertising ||
        vm.state == GamepadLinkState.connected;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: running ? () => vm.stop() : () => vm.connect(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: running
                    ? AppColors.border
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                running ? '停止' : '启动广播',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: running ? AppColors.secondary : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '链路：${label[vm.state]}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
                if (vm.error != null)
                  Text(
                    '启动失败：${vm.error}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
              ],
            ),
          ),
          Text(
            '已发 ${vm.frames} 帧',
            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

/// 延迟测试开关行：心跳模式（需与被控端连同一 Wi-Fi）
class _LatencyBar extends StatelessWidget {
  const _LatencyBar({required this.vm});

  final GamepadViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => vm.setLatencyTest(!vm.latencyTestOn),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: vm.latencyTestOn
                    ? AppColors.border
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                vm.latencyTestOn ? '停止测量' : '延迟测试',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: vm.latencyTestOn
                      ? AppColors.secondary
                      : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              vm.latencyTestOn ? '心跳测试中（200ms）——请勿触碰屏幕' : '与被控端连同一 Wi-Fi 后开始',
              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部回显：最近一帧的十六进制 + 当前按下的键
class _Readout extends StatelessWidget {
  const _Readout({required this.vm});

  final GamepadViewModel vm;

  @override
  Widget build(BuildContext context) {
    final r = vm.report;
    final names = <String>[
      if (r.pressed(GamepadButton.a)) 'A',
      if (r.pressed(GamepadButton.b)) 'B',
      if (r.pressed(GamepadButton.x)) 'X',
      if (r.pressed(GamepadButton.y)) 'Y',
      if (r.pressed(GamepadButton.l1)) 'L1',
      if (r.pressed(GamepadButton.r1)) 'R1',
      if (r.pressed(GamepadButton.back)) 'Back',
      if (r.pressed(GamepadButton.start)) 'Start',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '报告：${vm.lastBytesHex}',
            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
          const SizedBox(height: 2),
          Text(
            names.isEmpty ? '（无按键）' : '按下：${names.join(' ')}',
            style: const TextStyle(fontSize: 12, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

/// ABXY 菱形键位（Xbox 布局：Y 上、X 左、B 右、A 下）
class _AbxyCluster extends StatelessWidget {
  const _AbxyCluster({required this.vm, required this.report});

  final GamepadViewModel vm;
  final GamepadReport report;

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, int mask) => _PadButton(
          label: label,
          pressed: report.pressed(mask),
          onDown: () => vm.setButton(mask, true),
          onUp: () => vm.setButton(mask, false),
        );
    return Column(
      children: [
        btn('Y', GamepadButton.y),
        Row(
          children: [
            btn('X', GamepadButton.x),
            const SizedBox(width: AppSpacing.lg),
            btn('B', GamepadButton.b),
          ],
        ),
        btn('A', GamepadButton.a),
      ],
    );
  }
}

/// 十字键（支持对角：同时按两向 = hat 斜向值）
class _Dpad extends StatelessWidget {
  const _Dpad({required this.hat, required this.vm});

  final int hat;
  final GamepadViewModel vm;

  @override
  Widget build(BuildContext context) {
    final up = const [0, 1, 7].contains(hat);
    final right = const [1, 2, 3].contains(hat);
    final down = const [3, 4, 5].contains(hat);
    final left = const [5, 6, 7].contains(hat);
    Widget dir(String text, int idx, bool pressed) => _PadButton(
          label: text,
          size: 44,
          pressed: pressed,
          onDown: () => vm.setDpad(idx, true),
          onUp: () => vm.setDpad(idx, false),
        );
    return Column(
      children: [
        dir('↑', 0, up),
        Row(
          children: [
            dir('←', 3, left),
            const SizedBox(width: AppSpacing.lg),
            dir('→', 1, right),
          ],
        ),
        dir('↓', 2, down),
      ],
    );
  }
}

/// 圆形/胶囊按键：按下变实心（快照驱动 + 手势回传）
class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.pressed,
    required this.onDown,
    required this.onUp,
    this.size = 56,
    this.wide = false,
  });

  final String label;
  final bool pressed;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double size;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: onUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: wide ? size * 1.6 : size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(wide ? AppRadius.md : size / 2),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: pressed ? AppColors.neutral : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// 虚拟摇杆：拖动出轴值（-1..1），松手回中；位置由快照回推
class _Stick extends StatelessWidget {
  const _Stick({
    required this.lx,
    required this.ly,
    required this.onMove,
  });

  final double lx;
  final double ly;
  final void Function(double dx, double dy) onMove;

  static const double _box = 128;
  static const double _knob = 52;

  @override
  Widget build(BuildContext context) {
    const max = (_box - _knob) / 2;
    final dx = ((lx - 128) / 127).clamp(-1.0, 1.0);
    final dy = ((ly - 128) / 127).clamp(-1.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => _handle(d.localPosition),
      onPanUpdate: (d) => _handle(d.localPosition),
      onPanEnd: (_) => onMove(0, 0),
      child: Container(
        width: _box,
        height: _box,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: _box / 2 - _knob / 2 + dx * max,
              top: _box / 2 - _knob / 2 + dy * max,
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handle(Offset local) {
    const max = (_box - _knob) / 2;
    final dx = ((local.dx - _box / 2) / max).clamp(-1.0, 1.0);
    final dy = ((local.dy - _box / 2) / max).clamp(-1.0, 1.0);
    onMove(dx, dy);
  }
}

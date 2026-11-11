//! 启动更新门（boot update gate）：进主界面前的自动更新画面
//!
//! 游戏式启动体验（参考明日方舟等手游的启动热更页）：进门先检查更新，
//! 有热更/大版本就地处理（下载 → 重启生效 / 调起安装器），没有就秒过。
//! 纯 widgets（AppScaffold 页面壳自带文字基线，见 PITFALLS #28）；
//! 无图标（新增 LucideIcons 字形会改变 lucide.ttf 资产拦住 patch，PITFALLS #27）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_button.dart';
import '../../design/widgets/app_scaffold.dart';
import '../../design/widgets/app_spinner.dart';
import '../selftest/self_test_prompt.dart';
import 'boot_gate_controller.dart';

class BootGate extends StatefulWidget {
  const BootGate({super.key, required this.child});

  /// 放行后展示的主界面（HomePage）
  final Widget child;

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final BootGateController _controller = BootGateController()..start();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.done) {
          // 放行后挂自动测试入口（更新后首启/通知点击时机到了才弹，不拦主页）
          return SelfTestPrompt(child: widget.child);
        }
        return AppScaffold(body: _GateBody(controller: _controller));
      },
    );
  }
}

class _GateBody extends StatelessWidget {
  const _GateBody({required this.controller});

  final BootGateController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Spacer(),
            // 标识区：无 logo 资产，用应用名占位（DESIGN.md 未定义品牌字阶）
            const Text('my_app', style: AppTypography.h1),
            const SizedBox(height: AppSpacing.xs),
            const Text('个人工具箱', style: AppTypography.labelSm),
            const SizedBox(height: AppSpacing.lg),
            // 进度区
            if (phase == BootGatePhase.versionDownloading)
              SizedBox(
                width: 240,
                child: ShadProgress(value: controller.progress),
              )
            else
              const AppSpinner(size: 28),
            const SizedBox(height: AppSpacing.md),
            Text(
              controller.status,
              style: AppTypography.labelSm,
              textAlign: TextAlign.center,
            ),
            if (controller.message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                controller.message!,
                style: AppTypography.labelSm.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            // 底部操作：「跳过」全程可见（绝不把用户堵在门外）；
            // 重启降级态额外给「退出应用」（重开即应用热更）
            if (phase == BootGatePhase.restartPending) ...[
              AppButton(variant: AppButtonVariant.outline,
                onPressed: controller.exitApp,
                label: '退出应用',
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (phase != BootGatePhase.restarting)
              AppButton(variant: AppButtonVariant.ghost,
                onPressed: controller.skip,
                label: '跳过',
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

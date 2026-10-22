//! 设备互联方案页：控制端/被控端互联的方案文档（功能开发中）
//!
//! 本页当前只承载方案文本（v0.1 讨论稿），后续功能实现后
//! 会替换为真实的配对/控制界面。方案变更时同步更新本页内容。
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_section.dart';

class DeviceLinkPage extends StatelessWidget {
  const DeviceLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: '设备互联'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _StatusBanner(),
          SizedBox(height: AppSpacing.md),
          AppSection(
            title: '目标',
            children: [
              AppParagraph('两台手机通过本应用互联：一台作为控制端，一台作为被控端。'
                  '同一份 App 兼任两种角色，配对后自动认领角色，不做两个应用。'),
            ],
          ),
          AppSection(
            title: '总体架构',
            children: [
              _Mono('控制端 Controller            被控端 Device\n'
                  '┌────────────┐  蓝牙/WiFi/星闪  ┌────────────┐\n'
                  '│ 指令面板   │ ⇄    链路层    ⇄ │ 指令执行器 │\n'
                  '│ 状态回显   │                  │ 能力上报   │\n'
                  '└────────────┘                  └────────────┘'),
              SizedBox(height: AppSpacing.sm),
              AppParagraph('三个关键设计：'),
              AppBullet('链路抽象层（Transport 接口）：BLE / WiFi / 星闪各实现一个'
                  '传输接口，业务层只认"消息通道"。新增链路不影响业务代码。'),
              AppBullet('指令模型 = 能力声明：被控端上报"我能做什么"，控制端按能力'
                  '清单动态渲染控制面板。这也是后续 MCP 工具描述的雏形。'),
              AppBullet('配对即信任：NFC 碰一碰 / 扫码交换公钥，会话加密 + 设备白名单，'
                  '安全从第一版就有。'),
            ],
          ),
          AppSection(
            title: '链路选型',
            children: [
              AppBullet('BLE：控制指令与小数据的首选——低功耗、发现快、普及率高。'),
              AppBullet('WiFi（局域网 mDNS / 直连）：屏幕流、文件等大数据通道。'),
              AppBullet('星闪 NearLink：低时延理想链路，目前机型与 SDK 有限，'
                  '以 Transport 接口预留，待生态成熟接入。'),
              AppBullet('NFC：只做碰一碰配对（交换公钥/地址），不承载业务数据。'),
            ],
          ),
          AppSection(
            title: '协议分层',
            children: [
              AppBullet('发现层：BLE 广播 / mDNS 服务发现 / NFC 触碰交换。'),
              AppBullet('会话层：配对握手、密钥协商、心跳保活、断线重连。'),
              AppBullet('消息层：统一帧（类型/序号/负载/确认），'
                  '覆盖指令、事件上报与数据流三种形态。'),
            ],
          ),
          AppSection(
            title: '安全设计',
            children: [
              AppBullet('配对：扫码或 NFC 碰一碰交换设备公钥，配对码二次确认。'),
              AppBullet('传输：会话密钥加密（密钥协商 + 对称加密），防窃听防篡改。'),
              AppBullet('信任管理：设备白名单，可撤销、可忘记设备。'),
            ],
          ),
          AppSection(
            title: '里程碑（对应 ROADMAP Phase 1→3）',
            children: [
              AppBullet('① 配对 + BLE 文本指令互通（打通最小闭环）'),
              AppBullet('② WiFi 大数据通道（文件/屏幕流）'),
              AppBullet('③ 指令模型与动态控制面板'),
              AppBullet('④ 星闪 Transport 接入（视生态与 SDK）'),
            ],
          ),
          AppSection(
            title: '开放讨论点',
            children: [
              AppBullet('控制端桌面版的形态：桌面作为控制端遥控手机（ROADMAP Phase 3）。'),
              AppBullet('被控端可执行的指令边界：先做信息查询类还是开放输入转发？'),
              AppBullet('星闪的预期：与蓝牙双链路并存，还是作为蓝牙的替代？'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶部状态横幅：提示功能阶段
class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(LucideIcons.wrench, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '方案讨论阶段 · 功能开发中（v0.1 草案）',
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

/// 等宽文本块（架构图）
class _Mono extends StatelessWidget {
  const _Mono(this.text);

  final String text;

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
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

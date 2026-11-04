//! 功能注册表：全应用功能的唯一登记处，含平台能力声明
//!
//! 新功能在此登记一条（图标/标题/页面构建器/平台支持），
//! 首页自动展示；当前平台不支持的功能自动隐藏，
//! 受限功能标注说明——不允许"点进去才发现不能用"（docs/VISION.md）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/component_gallery/component_gallery_page.dart';
import '../features/device_link/device_link_page.dart';
import '../features/gamepad/gamepad_home_page.dart';
import '../features/hermes/hermes_home_page.dart';
import '../features/live2d/live2d_page.dart';
import '../features/notes/notes_list_page.dart';
import '../features/robot_eyes/robot_eye_page.dart';
import '../features/dsh_chat/dsh_chat_page.dart';
import '../features/vscreen/vscreen_page.dart';

/// 平台对功能的支持程度
enum PlatformSupport {
  /// 完整支持
  full,

  /// 受限支持（入口保留，标注 limitedNote）
  limited,

  /// 不支持（入口隐藏）
  none,
}

/// 单个功能的登记信息
class FeatureEntry {
  const FeatureEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.desktop = PlatformSupport.full,
    this.mobile = PlatformSupport.full,
    this.limitedNote,
  });

  /// 功能唯一标识（后续路由/配置/埋点用）
  final String id;

  /// 首页入口图标
  final IconData icon;

  /// 首页入口标题
  final String title;

  /// 首页入口副标题
  final String subtitle;

  /// 页面构建器（惰性构建，进入时才实例化）
  final WidgetBuilder builder;

  /// 桌面端（Windows/macOS/Linux）/ 移动端（Android/iOS）的支持程度
  final PlatformSupport desktop;
  final PlatformSupport mobile;

  /// 仅当 support 为 limited 时展示的说明
  final String? limitedNote;

  /// 当前平台对该功能的支持程度
  PlatformSupport get support {
    if (kIsWeb) return PlatformSupport.none; // Web 暂不在计划内
    if (Platform.isAndroid || Platform.isIOS) return mobile;
    return desktop;
  }
}

/// 全部功能（顺序 = 首页展示顺序）
///
/// 平台能力约定（docs/VISION.md · 平台能力矩阵）：
/// 通信/组网/分享在移动端为主战场，桌面端承载管理与控制类能力。
final List<FeatureEntry> kFeatures = [
  FeatureEntry(
    id: 'device_link',
    icon: LucideIcons.network,
    title: '设备互联',
    subtitle: '控制端 · 被控端 · 多链路组网',
    builder: (_) => const DeviceLinkPage(),
    // 通信组网以移动端为主战场（VISION · 平台能力矩阵）
    desktop: PlatformSupport.limited,
    limitedNote: '通信功能以移动端为主',
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'gamepad',
    icon: LucideIcons.gamepad2,
    title: '手柄控制',
    subtitle: '控制端 · 被控端 · 蓝牙 HID',
    builder: (_) => const GamepadHomePage(),
    // 控制端（HID 模拟）仅 Android 有真实现；桌面端为假链路调试
    desktop: PlatformSupport.limited,
    limitedNote: '桌面端仅假链路调试，无真蓝牙',
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'hermes',
    icon: LucideIcons.bot,
    title: 'Hermes',
    subtitle: '连接 gateway · 对话 · 工具流',
    builder: (_) => const HermesHomePage(),
    // Remote gateway 模式：连 PC/Mac/远程 gateway（协议见 docs/HERMES_GATEWAY_PROTOCOL.md）
    desktop: PlatformSupport.full,
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'dsh_chat',
    icon: LucideIcons.messageCircle,
    title: 'DSH 对话',
    subtitle: 'DeepSeek Harness · 会话 · 命令 · 流式',
    builder: (_) => const DshChatPage(),
    // 对话走 dsh web 协议（本机容器/远程），两端皆可
    desktop: PlatformSupport.full,
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'vscreen',
    icon: LucideIcons.monitor,
    title: '虚拟屏',
    subtitle: '预览 · 触控注入 · 手势缩放',
    builder: (_) => const VscreenPage(),
    // 虚拟屏 core（app_process）面向 Android；桌面无 core 进程
    desktop: PlatformSupport.limited,
    limitedNote: '虚拟屏 core 面向 Android，桌面无 core 进程',
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'component_gallery',
    icon: LucideIcons.layoutGrid,
    title: '组件库',
    subtitle: '统一组件 · 设计规范 · 实时示例',
    builder: (_) => const ComponentGalleryPage(),
  ),
  FeatureEntry(
    id: 'robot_eyes',
    icon: LucideIcons.eye,
    title: '机器人眼睛',
    subtitle: '表情 · 注视 · 眼睛动画',
    builder: (_) => const RobotEyePage(),
  ),
  FeatureEntry(
    id: 'live2d',
    icon: LucideIcons.sparkles,
    title: 'Live2D 看板娘',
    subtitle: 'Cubism 模型渲染 · 触摸跟踪 · 动作表情',
    builder: (_) => const Live2dPage(),
    // WebView 方案理论上跨平台（webview_flutter 支持桌面），桌面端未实测
    desktop: PlatformSupport.limited,
    limitedNote: '桌面端未实测，问题请反馈',
    mobile: PlatformSupport.full,
  ),
  FeatureEntry(
    id: 'notes',
    icon: LucideIcons.notebookPen,
    title: '记事本',
    subtitle: '记录想法与需求',
    builder: (_) => const NotesListPage(),
    // sqflite 仅支持移动端；桌面端待换 sqflite_common_ffi 后再开放
    desktop: PlatformSupport.none,
    mobile: PlatformSupport.full,
  ),
];

//! 功能注册表：全应用功能的唯一登记处，含平台能力声明
//!
//! 新功能在此登记一条（图标/标题/页面构建器/平台支持），
//! 首页自动展示；当前平台不支持的功能自动隐藏，
//! 受限功能标注说明——不允许"点进去才发现不能用"（docs/VISION.md）。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'notes/notes_list_page.dart';
import 'robot_eyes/robot_eye_page.dart';

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
    id: 'robot_eyes',
    icon: Icons.visibility_outlined,
    title: '机器人眼睛',
    subtitle: '表情 · 注视 · 眼睛动画',
    builder: (_) => const RobotEyePage(),
  ),
  FeatureEntry(
    id: 'notes',
    icon: Icons.edit_note,
    title: '记事本',
    subtitle: '记录想法与需求',
    builder: (_) => const NotesListPage(),
    // sqflite 仅支持移动端；桌面端待换 sqflite_common_ffi 后再开放
    desktop: PlatformSupport.none,
    mobile: PlatformSupport.full,
  ),
];

// SubApp: 微应用标准接口
// 每个子应用必须实现此接口，以便主应用动态发现和加载

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 微应用标准接口
/// 类似 Rust 的 trait 或 Python 的 abstract class
abstract class SubApp {
  /// 唯一标识（用于路由、注册表）
  /// 例如: 'auth', 'terminal', 'database'
  String get id;

  /// 显示名称（导航栏、菜单）
  String get name;

  /// 路由路径（必须以 / 开头）
  /// 例如: '/auth', '/terminal'
  String get route;

  /// 导航图标
  IconData get icon;

  /// 可选：选中状态图标
  IconData? get activeIcon => null;

  /// 应用描述
  String get description => '';

  /// 是否需要认证才能访问
  bool get requiresAuth => false;

  /// UI 入口（构建主页面）
  Widget builder(BuildContext context);

  /// 可选：配置该子应用的路由
  /// 如果子应用有多个页面，在此返回子路由
  List<RouteBase>? get routes => null;

  /// 可选：初始化回调（注册时调用一次）
  Future<void> onRegister(BuildContext context) async {}

  /// 可选：销毁回调（卸载时调用）
  Future<void> onUnregister() async {}

  /// 应用主题色（用于卡片、图标等 UI 元素）
  Color get color => const Color(0xFF6366F1); // 默认 Indigo

  /// 应用版本号（用于管理界面展示）
  String get version => '1.0.0';
}

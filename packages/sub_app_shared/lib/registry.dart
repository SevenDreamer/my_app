// SubAppRegistry: 微应用注册中心
// 类似 Python 的 sys.modules 或 Rust 的 inventory

import 'package:flutter/material.dart';
import 'sub_app.dart';

/// 微应用注册表
/// 主应用通过此类发现和加载所有子应用
class SubAppRegistry {
  // 私有存储：id -> SubApp
  static final Map<String, SubApp> _apps = {};

  // 注册顺序（用于导航栏排序）
  static final List<String> _order = [];

  // 子应用启用状态（内存缓存，持久化通过 SharedPreferences）
  static final Map<String, bool> _enabled = {};

  /// 注册子应用（类似 Python 的 import）
  /// 调用时机：main() 启动时
  static void register(SubApp app) {
    if (_apps.containsKey(app.id)) {
      debugPrint('Warning: SubApp "${app.id}" already registered, skipping.');
      return;
    }
    _apps[app.id] = app;
    _order.add(app.id);
    // 默认启用
    _enabled[app.id] ??= true;
    debugPrint('Registered SubApp: ${app.id} (${app.name})');
  }

  /// 批量注册
  static void registerAll(List<SubApp> apps) {
    for (final app in apps) {
      register(app);
    }
  }

  /// 动态加载子应用（类似 Python 的 __import__）
  /// [id]: 子应用 ID
  /// 返回 null 如果未注册
  static SubApp? load(String id) => _apps[id];

  /// 获取所有已注册子应用（按注册顺序）
  static List<SubApp> get all => _order.map((id) => _apps[id]!).toList();

  /// 获取所有已启用的子应用（按注册顺序）
  static List<SubApp> get enabled =>
      _order.where((id) => _enabled[id] ?? true).map((id) => _apps[id]!).toList();

  /// 获取所有已注册子应用（按名称排序）
  static List<SubApp> get allSortedByName =>
      all..sort((a, b) => a.name.compareTo(b.name));

  /// 是否已注册
  static bool isRegistered(String id) => _apps.containsKey(id);

  /// 子应用是否启用
  static bool isEnabled(String id) => _enabled[id] ?? true;

  /// 启用子应用
  static void enable(String id) {
    if (_apps.containsKey(id)) {
      _enabled[id] = true;
      debugPrint('Enabled SubApp: $id');
    }
  }

  /// 禁用子应用
  static void disable(String id) {
    if (_apps.containsKey(id)) {
      _enabled[id] = false;
      debugPrint('Disabled SubApp: $id');
    }
  }

  /// 切换子应用启用状态
  static void toggle(String id) {
    _enabled[id] = !(_enabled[id] ?? true);
    debugPrint('Toggled SubApp: $id -> ${_enabled[id]}');
  }

  /// 卸载子应用（热卸载，高级功能）
  static void unregister(String id) {
    _apps.remove(id);
    _order.remove(id);
    _enabled.remove(id);
    debugPrint('Unregistered SubApp: $id');
  }

  /// 清空所有（用于测试或重置）
  static void clear() {
    _apps.clear();
    _order.clear();
    _enabled.clear();
  }
}

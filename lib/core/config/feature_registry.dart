import 'package:flutter/widgets.dart';
import 'package:my_app/core/models/sub_app.dart';

/// 功能模块注册表
///
/// 负责：
/// 1. 注册已安装的功能模块
/// 2. 记录各功能的可用状态（如 Rust 动态库是否存在）
/// 3. 提供过滤后的可用应用列表给 Launcher
class FeatureRegistry {
  FeatureRegistry._();

  /// 功能可用状态表 {appId: true/false}
  static final Map<String, bool> _availability = {};

  /// 功能页面构建器（延迟导入时用）
  static final Map<String, WidgetBuilder> _builders = {};

  /// 注册功能模块
  static void registerApp(String id, WidgetBuilder builder) {
    _builders[id] = builder;
    // 默认标记为可用（注册了就可用）
    _availability.putIfAbsent(id, () => true);
  }

  /// 设置功能可用状态
  static void setAvailable(String id, bool available) {
    _availability[id] = available;
  }

  /// 检查功能是否可用
  static bool isAppAvailable(String id) {
    return _availability[id] ?? false;
  }

  /// 获取所有可用的应用列表
  static List<SubApp> get visibleApps {
    return builtInApps
        .where((app) => isAppAvailable(app.id))
        .toList();
  }

  /// 获取功能的页面构建器（如果已注册）
  static WidgetBuilder? getBuilder(String id) => _builders[id];
}

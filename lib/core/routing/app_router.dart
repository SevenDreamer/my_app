import 'package:flutter/material.dart';

import '../../features/chat/chat_app.dart';
import '../../features/image/image_app.dart';
import '../../features/code/code_app.dart';
import '../../features/database/database_app.dart';
import '../../features/bar/bar_app.dart';

/// 应用路由映射表
///
/// 将路由路径映射到对应的 Widget 构建器
Map<String, Widget Function()> get appRoutes => {
      '/chat': () => const ChatApp(),
      '/image': () => const ImageApp(),
      '/code': () => const CodeApp(),
      '/database': () => const DatabaseManagerApp(),
      '/bar': () => const BarApp(),
    };

/// 根据路由获取对应的 Widget
Widget? getWidgetByRoute(String route) {
  final builder = appRoutes[route];
  if (builder != null) {
    return builder();
  }
  return null;
}

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// 子应用模型
class SubApp {
  const SubApp({
    required this.id,
    this.dbId = 0,
    required this.name,
    required this.description,
    required this.iconName,
    required this.color,
    required this.route,
    this.isEnabled = true,
  });

  /// 从 JSON 创建 SubApp
  factory SubApp.fromJson(Map<String, dynamic> json) {
    return SubApp(
      id: (json['app_name'] ?? '') as String,
      dbId: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: (json['display_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      iconName: (json['icon'] ?? 'circle') as String,
      color: _getAppColor((json['app_name'] ?? '') as String),
      route: (json['route'] ?? '') as String,
      isEnabled: (json['is_active'] ?? true) as bool,
    );
  }
  final String id; // app_name，用于标识应用
  final int dbId; // 数据库中的 id（整数），用于数据库操作
  final String name;
  final String description;
  final String iconName;
  final Color color;
  final String route;
  final bool isEnabled;

  /// 根据应用名称获取颜色
  static Color _getAppColor(String appName) {
    switch (appName) {
      case 'chat':
        return const Color(0xFF7C5CFC);
      case 'image':
        return const Color(0xFF57A6FF);
      case 'code':
        return const Color(0xFF4ECDC4);
      case 'database':
        return const Color(0xFFFF6B6B);
      case 'bar':
        return const Color(0xFFE8AA42);
      default:
        return const Color(0xFF6C5CE7);
    }
  }

  /// 获取 IconData
  IconData get icon => _getIconData(iconName);

  /// 根据图标名称获取 IconData
  static IconData _getIconData(String name) {
    switch (name) {
      case 'message_circle':
        return LucideIcons.messageCircle;
      case 'image':
        return LucideIcons.image;
      case 'code2':
        return LucideIcons.code;
      case 'database':
        return LucideIcons.database;
      case 'wine':
        return LucideIcons.wine;
      default:
        return LucideIcons.circle;
    }
  }
}

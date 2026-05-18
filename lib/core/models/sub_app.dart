import 'package:flutter/material.dart';

/// 子应用模型
class SubApp {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  final bool isEnabled;

  const SubApp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.builder,
    this.isEnabled = true,
  });
}

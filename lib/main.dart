//! 应用入口：MaterialApp + 全局主题
import 'package:flutter/material.dart';

import 'design/theme.dart';
import 'features/home/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'my_app',
      debugShowCheckedModeBanner: false,
      // 全局主题：DESIGN.md 设计 tokens 的唯一入口（简洁现代）
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}

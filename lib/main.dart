//! 应用入口：黑色主题 + LED 机器人眼睛首页
import 'package:flutter/material.dart';

import 'pages/robot_eye_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Eyes',
      debugShowCheckedModeBanner: false,
      // 深色主题打底，保证页面纯黑无杂色
      theme: ThemeData.dark(useMaterial3: true),
      home: const RobotEyePage(),
    );
  }
}

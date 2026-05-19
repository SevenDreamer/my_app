// 测试自动生成的 flutter_rust_bridge 绑定
// 运行：flutter run lib/test_frb_auto.dart -d windows

import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'rust/frb_generated.dart';

void main() {
  // 初始化 Flutter Rust Bridge
  RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _result = '点击测试';

  Future<void> _testGreet() async {
    try {
      final result = await RustLib().greet(name: 'Flutter');
      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _result = '错误: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('FRB 自动生成绑定测试')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _testGreet,
                child: const Text('测试 greet()'),
              ),
              const SizedBox(height: 20),
              Text('结果: $_result'),
            ],
          ),
        ),
      ),
    );
  }
}

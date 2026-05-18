// 简单的 flutter_rust_bridge 集成测试
// 运行：flutter run lib/test_frb_integration.dart

import 'package:flutter/material.dart';
import 'package:my_app/rust/frb_generated.dart';

// 导入生成的 API 包装函数
import 'rust/api/simple.dart';

void main() async {
  // 初始化 Flutter 绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 RustLib
  await RustLib.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _result = 'Testing...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testGreet();
  }

  Future<void> _testGreet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // greet() 是同步函数，返回 String，不需要 await
      final result = greet(name: 'Flutter Rust Bridge');
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FRB Integration Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    _result,
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _testGreet,
              child: const Text('Test Greet'),
            ),
          ],
        ),
      ),
    );
  }
}

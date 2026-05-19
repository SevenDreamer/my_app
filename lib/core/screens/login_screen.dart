// 临时禁用：需要重构为 flutter_rust_bridge API
//
// 问题：
// 1. 引用了已删除的 ffi_auth.dart
// 2. 需要迁移到 flutter_rust_bridge 自动生成的 API
//
// 重构时参考：lib/rust/rust_generated.dart 中的 RustLib 类

import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'My App 登录',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const Text('登录功能待重构（使用 flutter_rust_bridge）'),
          ],
        ),
      ),
    );
  }
}

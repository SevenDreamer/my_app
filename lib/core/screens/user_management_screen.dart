// 临时禁用：需要重构为 flutter_rust_bridge API
//
// 问题：
// 1. 引用了已删除的 AuthFFI (ffi_auth.dart)
// 2. Shadcn Flutter 组件用法错误（AlertDialog、TextField 等不是函数）
// 3. 需要迁移到 flutter_rust_bridge 自动生成的 API
//
// 重构时参考：lib/rust/rust_generated.dart 中的 RustLib 类

import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('用户管理 - 待重构（使用 flutter_rust_bridge）'),
      ),
    );
  }
}

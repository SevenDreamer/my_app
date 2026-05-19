// 测试手动 FFI 集成
// 运行：flutter run lib/test_manual_ffi.dart -d windows

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

// FFI 绑定
final DynamicLibrary _dylib = DynamicLibrary.open('my_app.dll');

// 绑定 Rust 函数
final _ping = _dylib
    .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>('ping');

final _getCoreVersion =
    _dylib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
        'get_core_version');

final _freeString = _dylib.lookupFunction<Void Function(Pointer<Utf8>),
    void Function(Pointer<Utf8>)>('free_string');

String _fromCString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) return '';
  final result = ptr.toDartString();
  _freeString(ptr);
  return result;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _pingResult = '点击测试';
  String _versionResult = '点击获取版本';

  void _testPing() {
    final ptr = _ping();
    setState(() {
      _pingResult = _fromCString(ptr);
    });
  }

  void _testVersion() {
    final ptr = _getCoreVersion();
    setState(() {
      _versionResult = _fromCString(ptr);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('手动 FFI 测试')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _testPing,
                child: const Text('测试 ping'),
              ),
              Text('Ping 结果: $_pingResult'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testVersion,
                child: const Text('获取版本'),
              ),
              Text('版本: $_versionResult'),
            ],
          ),
        ),
      ),
    );
  }
}

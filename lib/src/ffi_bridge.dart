// ffi_bridge.dart - 手动编写的 FFI 桥接
// 临时方案：绕过 flutter_rust_bridge_codegen 在 Windows 上的路径 bug

import 'dart:ffi' as ffi;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// HermesAgentFFI - FFI 绑定类
class HermesAgentFFI {
  static final HermesAgentFFI _instance = HermesAgentFFI._internal();
  factory HermesAgentFFI() => _instance;
  HermesAgentFFI._internal();

  // Rust 库
  late final ffi.DynamicLibrary _dylib;

  // 函数签名
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _greet;
  late final ffi.Pointer<ffi.Char> Function() _ping;
  late final ffi.Pointer<ffi.Char> Function() _getCoreVersion;
  late final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _initHermes;

  // 初始化
  void init() {
    // 加载 Rust 动态库
    // Windows: hermes_agent.dll
    // macOS: libhermes_agent.dylib
    // Linux: libhermes_agent.so
    _dylib = ffi.DynamicLibrary.open('hermes_agent.dll');

    // 查找函数
    _greet = _dylib
        .lookupFunction<
            ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
            ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('hermes_greet');

    _ping = _dylib
        .lookupFunction<ffi.Pointer<ffi.Char> Function(),
            ffi.Pointer<ffi.Char> Function()>('hermes_ping');

    _getCoreVersion = _dylib
        .lookupFunction<ffi.Pointer<ffi.Char> Function(),
            ffi.Pointer<ffi.Char> Function()>('hermes_get_core_version');

    _initHermes = _dylib
        .lookupFunction<
            ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
            ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('hermes_init');
  }

  // greet 函数
  String greet(String name) {
    final namePtr = name.toNativeUtf8();
    final resultPtr = _greet(namePtr);
    final result = resultPtr.toDartString();
    // 这里应该释放内存，但先简化
    return result;
  }

  // ping 函数
  String ping() {
    final resultPtr = _ping();
    final result = resultPtr.toDartString();
    return result;
  }

  // getCoreVersion 函数
  String getCoreVersion() {
    final resultPtr = _getCoreVersion();
    final result = resultPtr.toDartString();
    return result;
  }

  // initHermes 函数
  String initHermes(String logLevel) {
    final levelPtr = logLevel.toNativeUtf8();
    final resultPtr = _initHermes(levelPtr);
    final result = resultPtr.toDartString();
    return result;
  }
}

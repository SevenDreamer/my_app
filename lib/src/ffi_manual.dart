/// 手动 FFI 绑定（临时方案）
///
/// 调用 Rust 的 C ABI 接口。等 flutter_rust_bridge codegen 在 Windows 上
/// 修复后，替换为自动生成的绑定。
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

/// FFI 绑定类（单例模式）
class HermesFFI {
  static late final HermesFFI _instance;
  late final ffi.DynamicLibrary _dylib;

  /// 私有构造函数
  HermesFFI._() {
    if (Platform.isWindows) {
      _dylib = ffi.DynamicLibrary.open('hermes_agent.dll');
    } else if (Platform.isLinux) {
      _dylib = ffi.DynamicLibrary.open('libhermes_agent.so');
    } else if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.open('libhermes_agent.dylib');
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  /// 初始化 FFI（必须在调用任何方法前调用）
  static void init() {
    _instance = HermesFFI._();
  }

  /// 获取单例实例
  static HermesFFI get instance => _instance;

  // ==================== 函数签名定义 ====================

  /// init_hermes: 返回 CString 指针
  late final _initHermes = _dylib
      .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)>('init_hermes');

  /// get_core_version: 返回 CString 指针
  late final _getCoreVersion = _dylib
      .lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('get_core_version');

  /// ping: 返回 CString 指针
  late final _ping = _dylib
      .lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('ping');

  /// free_string: 释放 CString 指针
  late final _freeString = _dylib
      .lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('free_string');

  /// add: 简单加法测试
  late final _add = _dylib
      .lookupFunction<Int32 Function(Int32, Int32),
          int Function(int, int)>('add');

  /// llm_list_models: 返回 CString 指针（JSON）
  late final _llmListModels = _dylib
      .lookupFunction<Pointer<Utf8> Function(Pointer<Utf8>),
          Pointer<Utf8> Function(Pointer<Utf8>)>(
          'llm_list_models');

  // ==================== Dart 封装方法 ====================

  /// 初始化 Hermes
  String initHermes({String logLevel = 'info'}) {
    final logLevelC = logLevel.toNativeUtf8();
    final resultPtr = _initHermes(logLevelC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 获取 Core 版本号
  String getCoreVersion() {
    final resultPtr = _getCoreVersion();
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// Ping 测试
  String ping() {
    final resultPtr = _ping();
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }

  /// 加法测试
  int add(int a, int b) => _add(a, b);

  /// 获取 LLM 模型列表（返回 JSON 字符串）
  String llmListModels({String provider = 'deepseek'}) {
    final providerC = provider.toNativeUtf8();
    final resultPtr = _llmListModels(providerC);
    final result = resultPtr.toDartString();
    _freeString(resultPtr.cast());
    return result;
  }
}

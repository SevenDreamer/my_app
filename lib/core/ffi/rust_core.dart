//! Rust 核心引擎 FFI 封装（dart:ffi，2026-11-10）。
//!
//! 对接 `rust/core`（C ABI 零依赖）：Windows 加载 core.dll（exe 同目录），
//! Android 未来加载 libcore.so，web 端走 wasm（预留）。加载失败不抛出
//! （返回能力缺失态）——Rust 核心是增强件不是必需件，UI 不得因缺它崩。
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Rust 核心能力句柄（null = 当前平台不可用）。
class RustCore {
  RustCore._(this._lib);

  final DynamicLibrary _lib;

  static RustCore? _instance;

  /// 尝试加载核心库（幂等；失败返回 null）。
  static RustCore? ensureLoaded() {
    if (_instance != null) return _instance;
    try {
      final lib = Platform.isWindows
          ? DynamicLibrary.open('core.dll')
          : DynamicLibrary.open('libcore.so');
      _instance = RustCore._(lib);
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// 心跳：核心版本（如 `core-rs-0.1.0`）；不可用返回 null。
  String? version() {
    try {
      final fn = _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
          'core_version');
      return fn().toDartString();
    } catch (_) {
      return null;
    }
  }

  /// 自检算术（FFI 双向通路验证）。
  int? add(int a, int b) {
    try {
      final fn = _lib.lookupFunction<Int64 Function(Int64, Int64),
          int Function(int, int)>('core_add');
      return fn(a, b);
    } catch (_) {
      return null;
    }
  }

  /// 构建信息（堆字符串，配对释放）。
  String? buildInfo() {
    try {
      final get = _lib.lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('core_build_info');
      final free = _lib.lookupFunction<Void Function(Pointer<Utf8>),
          void Function(Pointer<Utf8>)>('core_string_free');
      final p = get();
      if (p == nullptr) return null;
      final s = p.toDartString();
      free(p);
      return s;
    } catch (_) {
      return null;
    }
  }
}

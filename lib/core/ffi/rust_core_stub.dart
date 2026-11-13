//! RustCore 的 web/wasm 降级桩（条件导入用）。
//!
//! wasm/js 无 dart:ffi——本桩让 API 全部优雅降级（返回 null/0），
//! 与真件（rust_core.dart）同签名；调用侧经条件导入按平台选件。
/// 桩：Rust 核心在 web 不可用（将来 wasm 版核心经 JS 互操作接入）。
class RustCore {
  RustCore._();

  static RustCore? ensureLoaded({String? libraryPath}) => null;

  String? version() => null;

  int? add(int a, int b) => null;

  String? buildInfo() => null;

  String? sha256Hex(List<int> bytes) => null;

  bool? isVersionNewer(String remote, String current) => null;

  String? sha256File(String path) => null;
}

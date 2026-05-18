pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
// 在 Windows 上 codegen 有路径 bug，暂时用手动 FFI 桥接
// mod frb_generated;

pub mod ffi_manual;
pub mod database;

// 暂时只导出 ffi_manual（手动 FFI）
// api::simple 中的函数等 codegen 修复后再启用
pub use ffi_manual::*;

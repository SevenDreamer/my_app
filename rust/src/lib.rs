pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
// 在 Windows 上 codegen 有路径 bug，暂时用手动 FFI 桥接
// mod frb_generated;

pub mod ffi_manual;
pub mod ffi_auth;
pub mod database;
pub mod auth;

// 导出所有手动 FFI 函数
pub use ffi_manual::*;
pub use ffi_auth::*;

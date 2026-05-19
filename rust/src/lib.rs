// 临时方案：只使用手动 FFI，等 flutter_rust_bridge 在 Windows 上稳定后再启用
//
// pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
// mod frb_generated;

// 手动 FFI 模块
pub mod macros;
pub mod ffi_manual;
pub mod ffi_auth;
pub mod database;
pub mod auth;

// 导出所有手动 FFI 函数（使用 #[no_mangle] pub extern "C" 导出）
pub use ffi_manual::*;
pub use ffi_auth::*;

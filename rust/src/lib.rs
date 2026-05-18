pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
mod frb_generated;

// 手动 FFI（旧代码，待迁移到 flutter_rust_bridge）
pub mod macros;
pub mod ffi_manual;
pub mod ffi_auth;
pub mod database;
pub mod auth;

// 导出所有手动 FFI 函数（旧代码）
pub use ffi_manual::*;
pub use ffi_auth::*;

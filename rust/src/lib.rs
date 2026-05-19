// Flutter Rust Bridge 自动生成绑定（已修复 Windows FFI 符号导出问题）
pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
mod frb_generated;

// 手动 FFI 模块（备用，逐渐迁移到 flutter_rust_bridge）
pub mod macros;
pub mod ffi_manual;
pub mod ffi_auth;
pub mod database;
pub mod auth;

// 导出手动 FFI 函数（与自动生成共存）
pub use ffi_manual::*;
pub use ffi_auth::*;

// Flutter Rust Bridge 自动生成绑定（已修复 Windows FFI 符号导出问题）
pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
pub mod frb_generated;

// 手动 FFI 模块（备用，逐渐迁移到 flutter_rust_bridge）
pub mod macros;
pub mod ffi_auth;
pub mod database;
pub mod local_auth;  // 原 auth.rs，本地数据库认证

// 导出手动 FFI 函数（与自动生成共存）
pub use ffi_auth::*;

pub mod api;
// frb_generated 由 flutter_rust_bridge_codegen 生成
mod frb_generated;

// 导出 Flutter Rust Bridge 需要的 FFI 函数
// 这些函数由 flutter_rust_bridge 宏生成，但需要显式导出

// 1. Content hash 检查
#[no_mangle]
pub extern "C" fn frb_get_rust_content_hash() -> i32 {
    // 与 frb_generated.rs 中的 FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH 一致
    1263667936
}

// 2. 异步 FFI 分发器
#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_primary(
    func_id: i32,
    port: flutter_rust_bridge::for_generated::MessagePort,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) {
    frb_generated::pde_ffi_dispatcher_primary_impl(func_id, port, ptr, rust_vec_len, data_len)
}

// 3. 同步 FFI 分发器
#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_sync(
    func_id: i32,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    frb_generated::pde_ffi_dispatcher_sync_impl(func_id, ptr, rust_vec_len, data_len)
}

// 手动 FFI（旧代码，待迁移到 flutter_rust_bridge）
pub mod macros;
pub mod ffi_manual;
pub mod ffi_auth;
pub mod database;
pub mod auth;

// 导出所有手动 FFI 函数（旧代码）
pub use ffi_manual::*;
pub use ffi_auth::*;

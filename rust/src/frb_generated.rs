// frb_generated.rs - 手动编写的最小化版本
// 注意：这是临时方案，等 flutter_rust_bridge_codegen 在 Windows 上修复后
// 应删除此文件并重新运行 codegen

#![allow(dead_code, non_snake_case, unused_imports)]

use flutter_rust_bridge::*;
use std::sync::OnceLock;

// 初始化（由 flutter_rust_bridge 自动调用）
pub fn setup() {
    static INIT: OnceLock<()> = OnceLock::new();
    INIT.get_or_init(|| {
        // 初始化日志等
    });
}

// 重新导出 simple.rs 中的函数，供 FFI 调用
pub use crate::api::simple::*;

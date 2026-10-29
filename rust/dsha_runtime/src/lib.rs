//! DSHA 重构核心：事务解包 / 文件身份 / 限额（Rust 系统面）。
//!
//! 来源 DSHA（MIT）`app/src/main/java/com/deepseekharness/app/{runtime,backup}`，
//! 现代化重构、行为契约不变。错误契约：原版 `IOException("CODE")` 的机器可读
//! 代号（`COLD_SPLIT_*` / `ARCHIVE_*` / `TAR_*` 等）在本 crate 中作为
//! `std::io::Error` 的错误文案逐字保留。
//!
//! 模块路线：limits / fs_identity / signed_members / control（支撑层）→
//! archive（归档边界）→ cold_split（双流解包 + 签名树 + 原子组装）。
// Windows 身份标识（volume_serial_number/file_index）目前仍是 unstable
//（windows_by_handle）；工作区构建一律 +nightly（AGENTS.md），按目标启门。
#![cfg_attr(windows, feature(windows_by_handle))]

pub mod archive;
pub mod budget;
pub mod cold_split;
pub mod control;
pub mod device_file_operations;
pub mod device_shell_policy;
pub mod ffi;
pub mod fs_identity;
pub mod legacy_tar;
pub mod limits;
pub mod signed_members;
pub mod std_fs;
pub mod vscreen_anchor_proof;

/// fd 钉定设备文件层（POSIX only；Windows 宿主不编译，Android/Linux 目标验证）。
#[cfg(unix)]
pub mod android_device_files;

/// 构造携带机器可读代号的 IO 错误（对应原版 `IOException("CODE")`）。
pub fn code_error(code: impl Into<String>) -> std::io::Error {
    std::io::Error::other(code.into())
}

/// 唯一名（候选目录/暂存文件用；纳秒 + 计数器，等价 UUID.randomUUID 的用途）。
pub fn unique_name() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static UNIQUE: AtomicU64 = AtomicU64::new(0);
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{nanos:x}-{}", UNIQUE.fetch_add(1, Ordering::Relaxed))
}

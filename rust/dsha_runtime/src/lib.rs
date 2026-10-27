//! DSHA 重构核心：事务解包 / 文件身份 / 限额（Rust 系统面）。
//!
//! 来源 DSHA（MIT）`app/src/main/java/com/deepseekharness/app/{runtime,backup}`，
//! 现代化重构、行为契约不变。错误契约：原版 `IOException("CODE")` 的机器可读
//! 代号（`COLD_SPLIT_*` / `ARCHIVE_*` / `TAR_*` 等）在本 crate 中作为
//! `std::io::Error` 的错误文案逐字保留。
//!
//! 模块路线：limits / fs_identity / signed_members / control（支撑层）→
//! archive（归档边界）→ cold_split（双流解包 + 签名树 + 原子组装）。

pub mod control;
pub mod fs_identity;
pub mod legacy_tar;
pub mod limits;
pub mod signed_members;

/// 构造携带机器可读代号的 IO 错误（对应原版 `IOException("CODE")`）。
pub fn code_error(code: impl Into<String>) -> std::io::Error {
    std::io::Error::other(code.into())
}

// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.BackupLimits —— 现代化重构，行为契约不变。
//! 所有限额针对实际读取量，不能信任 ZIP 或历史 tar 的声明。
//! 错误代号契约：`ARCHIVE_PATH` / `PATH_DEPTH` / `ROOT_ID` / `ARCHIVE_LIMIT`。

use crate::code_error;
use std::io;

/// 总字节上限（16 GiB）。
pub const BYTES: u64 = 16 * 1024 * 1024 * 1024;
pub const ENTRIES: usize = 100_000;
pub const DEPTH: usize = 64;
pub const LINKS: usize = 40;

/// 事务目录的读取器以 64 条为有界上限。创建端也必须使用同一上限；
/// 旧的 32 条创建门禁会在没有未完成事务时把正常更新永久挡住。
/// 这里只放宽历史记录数量，不删除任何旧原件或失败候选。
pub const TRANSACTION_RECORDS: usize = 64;

/// 活动主机日志有界；已完成原件另存历史根。
pub const HOST_OPERATION_ACTIVE_RECORDS: usize = 64;
pub const CONFIGURATION_OPERATION_ACTIVE_RECORDS: usize = 64;

pub const RECORD: usize = 16 * 1024;
pub const MANIFEST: usize = 2 * 1024 * 1024;
pub const METADATA: usize = 32 * 1024 * 1024;

/// 归档内相对路径校验（原版 `path()`）。
pub fn path(name: &str) -> io::Result<&str> {
    if name.len() > 2048
        || name.starts_with('/')
        || name.contains('\\')
        || name.contains('\0')
        || drive_letter(name)
    {
        return Err(code_error("ARCHIVE_PATH"));
    }
    if name.is_empty() {
        return Ok(name);
    }
    let parts: Vec<&str> = name.split('/').collect(); // 保留空段（= Java split("/", -1)）
    if parts.len() > DEPTH {
        return Err(code_error("PATH_DEPTH"));
    }
    for part in parts {
        if part.is_empty()
            || part == "."
            || part == ".."
            || part.contains('\n')
            || part.contains('\r')
        {
            return Err(code_error("ARCHIVE_PATH"));
        }
    }
    Ok(name)
}

/// Windows 盘符形态（`^[A-Za-z]:.*`）。
fn drive_letter(name: &str) -> bool {
    let bytes = name.as_bytes();
    bytes.len() >= 2 && bytes[0].is_ascii_alphabetic() && bytes[1] == b':'
}

/// 根标识（`[a-z][a-z0-9_-]{0,79}`）。
pub fn root(value: &str) -> io::Result<&str> {
    let ok = !value.is_empty()
        && value.len() <= 80
        && value.as_bytes()[0].is_ascii_lowercase()
        && value
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-');
    if ok {
        Ok(value)
    } else {
        Err(code_error("ROOT_ID"))
    }
}

/// 有界加法（原版 `add()`，负数/越界 = `ARCHIVE_LIMIT`）。
pub fn add(current: i64, next: i64, maximum: i64) -> io::Result<i64> {
    if next < 0 || current < 0 || next > maximum - current {
        return Err(code_error("ARCHIVE_LIMIT"));
    }
    Ok(current + next)
}

/// 归档碰撞键（原版 `collisionKey`：root + '/' + NFC 归一 + 小写）。
pub fn collision_key(root_id: &str, archive_path: &str) -> io::Result<String> {
    root(root_id)?;
    path(archive_path)?;
    use unicode_normalization::UnicodeNormalization;
    Ok(if archive_path.is_empty() {
        root_id.to_string()
    } else {
        let normalized: String = archive_path.nfc().collect();
        format!("{root_id}/{}", normalized.to_lowercase())
    })
}

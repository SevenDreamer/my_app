// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.BackupFileSystem /
// util.FileKind —— 现代化重构，行为契约不变。
//! 窄文件系统边界：生产实现使用 Android lstat/NOFOLLOW/fstat。
//! 身份契约：`Node` 的 type/key/device/mode 是防篡改比对的根；
//! 错误代号 `FILE_KIND_MISSING` / `FILE_KIND_UNKNOWN` / `UNSAFE_ROOT` /
//! `PARENT_LINK_OR_MISSING` / `PARENT_LINK` / `REFUSE_ROOT_DELETE` 原样保留。

use crate::code_error;
use crate::limits;
use std::io;
use std::path::{Path, PathBuf};

/// 内部文件类型保留历史序列化名；未知名字显式失败。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileKind {
    File,
    Directory,
    Link,
    Missing,
    Unreadable,
    Excluded,
    Special,
    Other,
}

impl FileKind {
    pub fn from_wire(name: &str) -> io::Result<Self> {
        Ok(match name {
            "FILE" => FileKind::File,
            "DIRECTORY" => FileKind::Directory,
            "LINK" => FileKind::Link,
            "MISSING" => FileKind::Missing,
            "UNREADABLE" => FileKind::Unreadable,
            "EXCLUDED" => FileKind::Excluded,
            "SPECIAL" => FileKind::Special,
            "OTHER" => FileKind::Other,
            _ => return Err(code_error("FILE_KIND_UNKNOWN")),
        })
    }

    pub fn wire(self) -> &'static str {
        match self {
            FileKind::File => "FILE",
            FileKind::Directory => "DIRECTORY",
            FileKind::Link => "LINK",
            FileKind::Missing => "MISSING",
            FileKind::Unreadable => "UNREADABLE",
            FileKind::Excluded => "EXCLUDED",
            FileKind::Special => "SPECIAL",
            FileKind::Other => "OTHER",
        }
    }
}

/// 文件身份节点（lstat 语义；`key` 为 inode 级身份标识）。
#[derive(Debug, Clone)]
pub struct Node {
    pub kind: FileKind,
    pub key: String,
    pub size: u64,
    pub modified: i64,
    pub device: u64,
    pub mode: u32,
}

impl Node {
    /// 全字段一致（原版 `Node.same()`）。
    pub fn same(&self, other: &Node) -> bool {
        self.kind == other.kind
            && self.key == other.key
            && self.size == other.size
            && self.modified == other.modified
            && self.device == other.device
            && self.mode == other.mode
    }
}

/// 身份一致（type/device/key；mode 单独比对——原版 `sameIdentity`）。
pub fn same_identity(a: &Node, b: &Node) -> bool {
    a.kind == b.kind && a.device == b.device && a.key == b.key
}

/// 目录身份必须保持（原版 `requireIdentity`）：`COLD_SPLIT_ROOT_CHANGED:<file>`。
pub fn require_identity(fs: &dyn Fs, file: &Path, expected: &Node) -> io::Result<()> {
    let actual = fs.stat(file)?;
    if expected.kind != FileKind::Directory
        || !same_identity(expected, &actual)
        || expected.mode != actual.mode
    {
        return Err(code_error(format!(
            "COLD_SPLIT_ROOT_CHANGED:{}",
            file.display()
        )));
    }
    Ok(())
}

/// 窄文件系统边界（原版 `BackupFileSystem` 接口）。
pub trait Fs {
    fn stat(&self, file: &Path) -> io::Result<Node>;
    fn read_link(&self, file: &Path) -> io::Result<String>;
    fn list(&self, directory: &Path) -> io::Result<Vec<String>>;
    fn directory(&self, file: &Path) -> io::Result<()>;
    fn move_path(&self, source: &Path, target: &Path) -> io::Result<()>;
    fn delete(&self, file: &Path) -> io::Result<()>;
    fn sync_directory(&self, directory: &Path) -> io::Result<()>;
    fn mode(&self, file: &Path, mode: u32) -> io::Result<()>;
    fn symlink(&self, target: &str, link: &Path) -> io::Result<()>;

    /// 安全拼接相对路径（逐段 lstat：根与父必须是真目录，防链接替换）。
    fn child(&self, root: &Path, relative: &str) -> io::Result<PathBuf> {
        limits::path(relative)?;
        let mut current = root.to_path_buf();
        if self.stat(&current)?.kind != FileKind::Directory {
            return Err(code_error("UNSAFE_ROOT"));
        }
        if relative.is_empty() {
            return Ok(current);
        }
        for part in relative.split('/') {
            if self.stat(&current)?.kind != FileKind::Directory {
                return Err(code_error("PARENT_LINK_OR_MISSING"));
            }
            current.push(part);
        }
        Ok(current)
    }

    /// 递归删除自有树（原版 `removeOwned`；拒删根本身）。
    fn remove_owned(&self, root: &Path, relative: &str) -> io::Result<()> {
        if relative.is_empty() {
            return Err(code_error("REFUSE_ROOT_DELETE"));
        }
        let target = self.child(root, relative)?;
        let node = self.stat(&target)?;
        if node.kind == FileKind::Missing {
            return Ok(());
        }
        if node.kind == FileKind::Directory {
            for name in self.list(&target)? {
                let child_rel = if relative.is_empty() {
                    name
                } else {
                    format!("{relative}/{name}")
                };
                self.remove_owned(root, &child_rel)?;
            }
        }
        if relative.is_empty() {
            return Err(code_error("REFUSE_ROOT_DELETE"));
        }
        self.delete(&target)
    }
}

// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.BackupFileSystem —— 现代化重构，行为契约不变。
//! 标准文件系统实现（桌面/测试宿主）。
//!
//! Android 的 TrustedAssetFs（fd 出生身份快路径）在原生接线轮接入；
//! 本实现满足 [Fs] 契约的 lstat 语义与身份比对（`Node.key` 取
//! device:inode 级标识，Windows 取 volume:file_index）。
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::path::Path;

use crate::code_error;
use crate::fs_identity::{FileKind, Fs, Node};

/// 真实文件系统边界。
pub struct StdFs;

fn kind_of(meta: &fs::Metadata) -> FileKind {
    let file_type = meta.file_type();
    if file_type.is_symlink() {
        FileKind::Link
    } else if file_type.is_dir() {
        FileKind::Directory
    } else if file_type.is_file() {
        FileKind::File
    } else {
        FileKind::Special
    }
}

#[cfg(unix)]
fn node_of(meta: &fs::Metadata) -> Node {
    use std::os::unix::fs::MetadataExt;
    Node {
        kind: kind_of(meta),
        key: format!("{}:{}", meta.dev(), meta.ino()),
        size: meta.size(),
        modified: meta.mtime() * 1_000_000_000 + i64::from(meta.mtime_nsec()),
        device: meta.dev(),
        mode: meta.mode() & 0o7777,
    }
}

#[cfg(windows)]
fn node_of(meta: &fs::Metadata) -> Node {
    use std::os::windows::fs::MetadataExt;
    // 身份标识取 volume 序列号 + 文件索引（无 inode 的等价物）。
    let volume = u64::from(meta.volume_serial_number().unwrap_or(0));
    let index = meta.file_index().unwrap_or(0);
    Node {
        kind: kind_of(meta),
        key: format!("{volume}:{index}"),
        size: meta.file_size(),
        modified: meta.last_write_time() as i64,
        device: volume,
        mode: if meta.permissions().readonly() { 0o444 } else { 0o666 },
    }
}

impl StdFs {
    fn checked_write(&self, file: &Path) -> io::Result<Box<dyn Write>> {
        Ok(Box::new(File::create(file)?))
    }
}

impl Fs for StdFs {
    /// lstat 语义：符号链接本身，不追目标。
    fn stat(&self, file: &Path) -> io::Result<Node> {
        let meta = fs::symlink_metadata(file);
        match meta {
            Ok(meta) => Ok(node_of(&meta)),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(Node {
                kind: FileKind::Missing,
                key: String::new(),
                size: 0,
                modified: 0,
                device: 0,
                mode: 0,
            }),
            Err(error) => Ok(Node {
                kind: FileKind::Unreadable,
                key: format!("ERR:{}", error),
                size: 0,
                modified: 0,
                device: 0,
                mode: 0,
            }),
        }
    }

    fn read_link(&self, file: &Path) -> io::Result<String> {
        Ok(fs::read_link(file)?.to_string_lossy().into_owned())
    }

    fn list(&self, directory: &Path) -> io::Result<Vec<String>> {
        let mut names = Vec::new();
        for entry in fs::read_dir(directory)? {
            names.push(entry?.file_name().to_string_lossy().into_owned());
        }
        Ok(names)
    }

    fn directory(&self, file: &Path) -> io::Result<()> {
        fs::create_dir_all(file)
    }

    fn move_path(&self, source: &Path, target: &Path) -> io::Result<()> {
        fs::rename(source, target)
    }

    fn delete(&self, file: &Path) -> io::Result<()> {
        // 原版 File.delete：文件或空目录。
        match fs::remove_file(file) {
            Ok(()) => Ok(()),
            Err(_) => fs::remove_dir(file),
        }
    }

    fn sync_directory(&self, directory: &Path) -> io::Result<()> {
        // 目录 fsync 为 POSIX 语义；Windows 不支持目录句柄 fsync，如实跳过。
        #[cfg(unix)]
        {
            File::open(directory)?.sync_all()
        }
        #[cfg(not(unix))]
        {
            let _ = directory;
            Ok(())
        }
    }

    fn mode(&self, file: &Path, mode: u32) -> io::Result<()> {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(file, fs::Permissions::from_mode(mode))
        }
        #[cfg(windows)]
        {
            // Windows 只映射写位（readonly 位）；其余位无对应语义。
            let readonly = mode & 0o200 == 0;
            let mut permissions = fs::metadata(file)?.permissions();
            permissions.set_readonly(readonly);
            fs::set_permissions(file, permissions)
        }
    }

    fn symlink(&self, target: &str, link: &Path) -> io::Result<()> {
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(target, link)
        }
        #[cfg(windows)]
        {
            // 目标可能是文件或目录；先按文件建，失败再按目录（Windows 双 API 语义）。
            std::os::windows::fs::symlink_file(target, link).or_else(|_| {
                std::os::windows::fs::symlink_dir(target, link)
            })
        }
    }

    fn create(&self, file: &Path) -> io::Result<Box<dyn Write>> {
        self.checked_write(file)
    }

    /// 身份校验读：先 lstat 全字段比对（TOCTOU 守卫，含 size/mtime），再打开。
    /// 失配错误 `FILE_OPERATION_IDENTITY:<file>`（被 TAR_ENTRY_FAILURE 包装上抛）。
    fn read_file(&self, file: &Path, expected: &Node) -> io::Result<Box<dyn Read>> {
        let actual = self.stat(file)?;
        if !expected.same(&actual) {
            return Err(code_error(format!(
                "FILE_OPERATION_IDENTITY:{}",
                file.display()
            )));
        }
        Ok(Box::new(File::open(file)?))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stat_lstat_semantics_and_identity() {
        let temp = std::env::temp_dir().join(format!("dsha-stdfs-{}", std::process::id()));
        fs::create_dir_all(&temp).unwrap();
        let file = temp.join("a.txt");
        fs::write(&file, b"hello").unwrap();
        let fsx = StdFs;
        let node = fsx.stat(&file).unwrap();
        assert_eq!(node.kind, FileKind::File);
        assert_eq!(node.size, 5);
        // 身份读：一致放行。
        let mut reader = fsx.read_file(&file, &node).unwrap();
        let mut body = String::new();
        reader.read_to_string(&mut body).unwrap();
        assert_eq!(body, "hello");
        // 身份读：改大小后失配。
        fs::write(&file, b"hello!").unwrap();
        let error = fsx
            .read_file(&file, &node)
            .err()
            .expect("identity mismatch expected");
        assert!(error.to_string().contains("FILE_OPERATION_IDENTITY"));
        fs::remove_dir_all(&temp).unwrap();
    }
}

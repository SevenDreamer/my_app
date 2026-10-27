// 版权来源：DSHA（MIT）com.deepseekharness.app.bridge.AndroidDeviceFiles —— 现代化重构，行为契约不变。
//! 固定父目录描述符的设备文件执行边界；没有 cp/mv/rm 子进程或沿用户链接回退。
//!
//! 原版经 `/proc/self/fd/N/<name>` 寻址（Java 无 openat）；本移植直接
//! `openat(parent_fd, name, NOFOLLOW)` —— 语义等价且同为"句柄钉定后逐级 NOFOLLOW"。
//! 错误代号契约（逐字）：`DEVICE_FILESYSTEM_<errno>`/`ABSOLUTE_PATH_REQUIRED`/
//! `STORAGE_ROOT_UNVERIFIED`/`PARENT_LINK_OR_MISSING`/`FILE_PARENT_CHANGED`/
//! `FILE_HANDLE_CLOSED`/`FILE_HANDLE_CLOSED_OR_ROOT`/`FILE_TARGET_CHANGED`/
//! `DIRECTORY_TARGET_CHANGED`/`PROTECTED_WRITE_PATH`/`LINK_OR_SPECIAL_FILE`/
//! `CHILD_NAME_INVALID`/`DIRECTORY_REQUIRED`/`DIRECTORY_UNREADABLE_OR_LIMIT`/
//! `MULTIPLE_FILE_LINKS`/`REGULAR_FILE_REQUIRED`/`READ_ONLY_HANDLE`/`FILE_EXISTS`/
//! `TOUCH_FAILED`/`FILE_HANDLE_MISMATCH`/`FILE_MISSING`/`FILE_TIME_FAILED`/
//! `MOVE_HANDLE_MISMATCH`/`MOVE_SOURCE_INVALID`/`MOVE_TARGET_EXISTS_OR_LINK`/
//! `ATOMIC_NOCLOBBER_MOVE_UNSUPPORTED`/`SMS_PROVIDER_READ_BLOCKED`。

use crate::device_file_operations::{Access, Entry};
use crate::device_shell_policy::{self, DeviceShellPolicy};
use rustix::fd::{AsFd, OwnedFd};
use rustix::fs::{self as rfs, AtFlags, Gid, Mode, OFlags, Uid};
use std::io::{self, Read, Write};
use std::path::Path;

const O_PATH_FLAGS: OFlags =
    OFlags::PATH.union(OFlags::CLOEXEC).union(OFlags::NOFOLLOW).union(OFlags::DIRECTORY);

fn failure(error: rustix::io::Errno) -> io::Error {
    io::Error::other(format!("DEVICE_FILESYSTEM_{}", error.raw_os_error()))
}

/// 设备文件执行边界（原版 `AndroidDeviceFiles`）。
pub struct AndroidDeviceFiles;

impl AndroidDeviceFiles {
    fn open_inner(
        &self,
        raw: &str,
        write: bool,
        parents: bool,
        inspect_only: bool,
    ) -> io::Result<Pinned> {
        let path = device_shell_policy::normalize(raw);
        if path.is_empty() {
            return Err(code("ABSOLUTE_PATH_REQUIRED"));
        }
        let root = if write {
            crate::device_file_operations::write_root(&DeviceShellPolicy, &path)?
        } else {
            "/".to_string()
        };
        let actual_root = std::fs::canonicalize(&root)
            .map_err(|_| code("STORAGE_ROOT_UNVERIFIED"))?;
        if write
            && device_shell_policy::normalize(&actual_root.to_string_lossy()) != root
        {
            return Err(code("STORAGE_ROOT_UNVERIFIED"));
        }
        let root_fd = rfs::openat(
            rfs::CWD,
            &actual_root,
            O_PATH_FLAGS,
            Mode::empty(),
        )
        .map_err(failure)?;
        let mut at = Pinned::new(root.clone(), None, "", Some(root_fd), write)?;
        let suffix = if root == "/" {
            path[1..].to_string()
        } else {
            path[root.len() + 1..].to_string()
        };
        if suffix.is_empty() {
            return Ok(at);
        }
        let parts: Vec<&str> = suffix.split('/').collect();
        for (i, part) in parts.iter().enumerate() {
            let mut next = at.child_pinned(part)?;
            if i + 1 < parts.len() && next.entry_type()? == "MISSING" && parents {
                if inspect_only {
                    return Ok(next);
                }
                next.make_directory()?;
            }
            if i + 1 < parts.len() && next.entry_type()? != "DIRECTORY" {
                return Err(code("PARENT_LINK_OR_MISSING"));
            }
            at = next;
        }
        Ok(at)
    }
}

impl Access for AndroidDeviceFiles {
    fn open(&self, path: &str, write: bool, parents: bool) -> io::Result<Box<dyn Entry>> {
        Ok(Box::new(self.open_inner(path, write, parents, false)?))
    }

    fn validate(&self, path: &str, write: bool, parents: bool) -> io::Result<()> {
        let mut entry = self.open_inner(path, write, parents, true)?;
        let kind = entry.entry_type()?;
        let result = if kind == "LINK" || kind == "SPECIAL" {
            Err(code("LINK_OR_SPECIAL_FILE"))
        } else {
            Ok(())
        };
        entry.close()?;
        result
    }
}

/// 钉定句柄条目（原版 `Pinned`）。
pub struct Pinned {
    logical: String,
    name: String,
    writable: bool,
    parent: Option<OwnedFd>,
    parent_binding: String,
    directory: Option<OwnedFd>,
    expected: Option<rfs::Stat>,
    closed: bool,
}

impl Pinned {
    fn new(
        logical: String,
        parent: Option<OwnedFd>,
        name: &str,
        directory: Option<OwnedFd>,
        writable: bool,
    ) -> io::Result<Self> {
        let parent_binding = match &parent {
            Some(fd) => readlink_fd(fd)?,
            None => String::new(),
        };
        if writable {
            if let Some(parent_fd) = &parent {
                let binding = device_shell_policy::normalize(&parent_binding);
                let expected_parent = Path::new(&logical)
                    .parent()
                    .map(|p| p.to_string_lossy().to_string())
                    .unwrap_or_default();
                let _ = parent_fd;
                if binding != expected_parent {
                    return Err(code("FILE_PARENT_CHANGED"));
                }
            }
        }
        let mut pinned = Pinned {
            logical,
            name: name.to_string(),
            writable,
            parent,
            parent_binding,
            directory,
            expected: None,
            closed: false,
        };
        pinned.expected = if pinned.parent.is_none() {
            Some(fstat_dir(pinned.directory.as_ref().expect("root directory"))?)
        } else {
            pinned.stat()?
        };
        let is_dir = pinned
            .expected
            .as_ref()
            .map(|s| rfs::FileType::from_raw_mode(s.st_mode) == rfs::FileType::Directory)
            .unwrap_or(false);
        if is_dir && pinned.directory.is_none() {
            pinned.pin_directory()?;
        }
        Ok(pinned)
    }

    fn stat(&self) -> io::Result<Option<rfs::Stat>> {
        let parent = self.parent.as_ref().ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?;
        match rfs::statat(parent, &self.name, AtFlags::SYMLINK_NOFOLLOW) {
            Ok(stat) => Ok(Some(stat)),
            Err(error) if error == rustix::io::Errno::NOENT => Ok(None),
            Err(error) => Err(failure(error)),
        }
    }

    fn same(a: Option<&rfs::Stat>, b: Option<&rfs::Stat>) -> bool {
        match (a, b) {
            (None, None) => true,
            (Some(a), Some(b)) => {
                a.st_dev == b.st_dev
                    && a.st_ino == b.st_ino
                    && file_type(a) == file_type(b)
            }
            _ => false,
        }
    }

    fn verify(&mut self) -> io::Result<()> {
        crate::device_file_operations::cancelled()?;
        if self.closed {
            return Err(code("FILE_HANDLE_CLOSED"));
        }
        if let Some(parent) = &self.parent {
            if readlink_fd(parent)? != self.parent_binding {
                return Err(code("FILE_PARENT_CHANGED"));
            }
        }
        if self.parent.is_some() && !Self::same(self.expected.as_ref(), self.stat()?.as_ref()) {
            return Err(code("FILE_TARGET_CHANGED"));
        }
        if let Some(directory) = &self.directory {
            if !Self::same(self.expected.as_ref(), Some(&fstat_fd(directory)?)) {
                return Err(code("DIRECTORY_TARGET_CHANGED"));
            }
        }
        if self.writable && self.parent.is_some() && !device_shell_policy::write_allowed(&self.logical)
        {
            return Err(code("PROTECTED_WRITE_PATH"));
        }
        Ok(())
    }

    fn pin_directory(&mut self) -> io::Result<()> {
        let parent = self.parent.as_ref().ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?;
        let fd = rfs::openat(
            parent,
            &self.name,
            OFlags::PATH | OFlags::CLOEXEC | OFlags::DIRECTORY | OFlags::NOFOLLOW,
            Mode::empty(),
        )
        .map_err(failure)?;
        if !Self::same(self.expected.as_ref(), Some(&fstat_fd(&fd)?)) {
            return Err(code("DIRECTORY_TARGET_CHANGED"));
        }
        self.directory = Some(fd);
        Ok(())
    }

    /// 逐级下钻（[Entry::child] 的具体型版本；open 走查需要 [Pinned] 语义）。
    fn child_pinned(&mut self, child: &str) -> io::Result<Pinned> {
        if child.is_empty()
            || child == "."
            || child == ".."
            || child.contains('/')
            || child.contains('\0')
        {
            return Err(code("CHILD_NAME_INVALID"));
        }
        if self.entry_type()? != "DIRECTORY" || self.directory.is_none() {
            return Err(code("DIRECTORY_REQUIRED"));
        }
        let copy = self
            .directory
            .as_ref()
            .ok_or_else(|| code("DIRECTORY_REQUIRED"))?
            .try_clone()?;
        let logical = if self.logical == "/" {
            format!("/{child}")
        } else {
            format!("{}/{}", self.logical, child)
        };
        Pinned::new(logical, Some(copy), child, None, self.writable)
    }

    fn file_handle(&mut self, flags: OFlags, mode: Mode) -> io::Result<OwnedFd> {
        self.verify()?;
        let parent = self.parent.as_ref().ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?;
        let fd = rfs::openat(
            parent,
            &self.name,
            flags | OFlags::CLOEXEC | OFlags::NOFOLLOW | OFlags::NONBLOCK,
            mode,
        )
        .map_err(failure)?;
        let opened = fstat_fd(&fd)?;
        let is_reg = file_type(&opened) == rfs::FileType::RegularFile;
        if !is_reg
            || (self.expected.is_some()
                && !Self::same(self.expected.as_ref(), Some(&opened)))
        {
            return Err(code("FILE_TARGET_CHANGED"));
        }
        if self.writable && opened.st_nlink > 1 {
            return Err(code("MULTIPLE_FILE_LINKS"));
        }
        Ok(fd)
    }
}

impl Entry for Pinned {
    fn path(&self) -> &str {
        &self.logical
    }

    fn name(&self) -> &str {
        &self.name
    }

    fn entry_type(&mut self) -> io::Result<String> {
        self.verify()?;
        Ok(match self.expected.as_ref().map(file_type) {
            None => "MISSING",
            Some(rfs::FileType::RegularFile) => "FILE",
            Some(rfs::FileType::Directory) => "DIRECTORY",
            Some(rfs::FileType::Symlink) => "LINK",
            Some(_) => "SPECIAL",
        }
        .to_string())
    }

    fn child(&mut self, child: &str) -> io::Result<Box<dyn Entry>> {
        Ok(Box::new(self.child_pinned(child)?))
    }

    fn names(&mut self) -> io::Result<Vec<String>> {
        if self.entry_type()? != "DIRECTORY" {
            return Err(code("DIRECTORY_REQUIRED"));
        }
        let directory = self.directory.as_ref().ok_or_else(|| code("DIRECTORY_REQUIRED"))?;
        let mut names = Vec::new();
        let entries = std::fs::read_dir(format!(
            "/proc/self/fd/{}",
            directory.as_fd().as_raw_fd()
        ))
        .map_err(|_| code("DIRECTORY_UNREADABLE_OR_LIMIT"))?;
        for entry in entries {
            let entry = entry.map_err(|_| code("DIRECTORY_UNREADABLE_OR_LIMIT"))?;
            names.push(entry.file_name().to_string_lossy().to_string());
        }
        if names.len() > 20000 {
            return Err(code("DIRECTORY_UNREADABLE_OR_LIMIT"));
        }
        names.sort();
        self.entry_type()?;
        Ok(names)
    }

    fn read(&mut self) -> io::Result<Box<dyn Read>> {
        if self.entry_type()? != "FILE" {
            return Err(code("REGULAR_FILE_REQUIRED"));
        }
        let fd = self.file_handle(OFlags::RDONLY, Mode::empty())?;
        let actual = readlink_fd(&fd)?;
        if device_shell_policy::sms_provider_path(&actual) {
            return Err(code("SMS_PROVIDER_READ_BLOCKED"));
        }
        Ok(Box::new(std::fs::File::from(fd)))
    }

    fn write(&mut self) -> io::Result<Box<dyn Write>> {
        if !self.writable || !device_shell_policy::write_allowed(&self.logical) {
            return Err(code("READ_ONLY_HANDLE"));
        }
        let kind = self.entry_type()?;
        if kind != "FILE" && kind != "MISSING" {
            return Err(code("REGULAR_FILE_REQUIRED"));
        }
        // 不能在 open 时截断：先核对已打开的 inode 与 hard-link 数，再执行 ftruncate。
        let flags = if self.expected.is_none() {
            OFlags::WRONLY | OFlags::CREATE | OFlags::EXCL
        } else {
            OFlags::WRONLY
        };
        let fd = self.file_handle(flags, Mode::from_bits_truncate(0o644))?;
        self.expected = Some(fstat_fd(&fd)?);
        rfs::ftruncate(&fd, 0).map_err(failure)?;
        Ok(Box::new(std::fs::File::from(fd)))
    }

    fn make_directory(&mut self) -> io::Result<()> {
        if !self.writable || !device_shell_policy::write_allowed(&self.logical) {
            return Err(code("READ_ONLY_HANDLE"));
        }
        self.verify()?;
        if self.expected.is_some() {
            return Err(code("FILE_EXISTS"));
        }
        let parent = self.parent.as_ref().ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?;
        rfs::mkdirat(parent, &self.name, Mode::from_bits_truncate(0o755))
            .map_err(failure)?;
        self.expected = self.stat()?;
        self.pin_directory()
    }

    fn touch(&mut self) -> io::Result<()> {
        if !self.writable || !device_shell_policy::write_allowed(&self.logical) {
            return Err(code("READ_ONLY_HANDLE"));
        }
        if self.entry_type()? == "MISSING" {
            drop(self.write()?);
            return Ok(());
        }
        let kind = self.entry_type()?;
        let fd = if kind == "DIRECTORY" {
            self.directory
                .as_ref()
                .ok_or_else(|| code("DIRECTORY_REQUIRED"))?
                .try_clone()?
        } else {
            self.file_handle(OFlags::WRONLY, Mode::empty())?
        };
        set_now(&fd).map_err(|_| code("TOUCH_FAILED"))
    }

    fn metadata_to(&mut self, target: &mut dyn Entry) -> io::Result<()> {
        let target = target
            .as_any_mut()
            .downcast_mut::<Pinned>()
            .ok_or_else(|| code("FILE_HANDLE_MISMATCH"))?;
        if !target.writable || !device_shell_policy::write_allowed(&target.logical) {
            return Err(code("READ_ONLY_HANDLE"));
        }
        self.verify()?;
        target.verify()?;
        let expected = self.expected.ok_or_else(|| code("FILE_MISSING"))?;
        let mtime = expected.st_mtime;
        if target.entry_type()? == "DIRECTORY" {
            let fd = target
                .directory
                .as_ref()
                .ok_or_else(|| code("DIRECTORY_REQUIRED"))?;
            rfs::fchmod(fd, Mode::from_bits_truncate(expected.st_mode as u32 & 0o777))
                .map_err(failure)?;
            rfs::fchown(fd, Some(Uid::from_raw(expected.st_uid)), Some(Gid::from_raw(expected.st_gid)))
                .map_err(failure)?;
            set_mtime(fd, mtime).map_err(|_| code("FILE_TIME_FAILED"))
        } else {
            let fd = target.file_handle(OFlags::WRONLY, Mode::empty())?;
            rfs::fchmod(&fd, Mode::from_bits_truncate(expected.st_mode as u32 & 0o777))
                .map_err(failure)?;
            rfs::fchown(&fd, Some(Uid::from_raw(expected.st_uid)), Some(Gid::from_raw(expected.st_gid)))
                .map_err(failure)?;
            set_mtime(&fd, mtime).map_err(|_| code("FILE_TIME_FAILED"))
        }
    }

    fn delete(&mut self) -> io::Result<()> {
        if !self.writable || !device_shell_policy::write_allowed(&self.logical) {
            return Err(code("READ_ONLY_HANDLE"));
        }
        self.verify()?;
        if self.expected.is_none() {
            return Err(code("FILE_MISSING"));
        }
        let parent = self.parent.as_ref().ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?;
        rfs::unlinkat(parent, &self.name, AtFlags::empty()).map_err(failure)?;
        self.expected = None;
        Ok(())
    }

    fn move_to(&mut self, target: &mut dyn Entry, no_clobber: bool) -> io::Result<()> {
        let target = target
            .as_any_mut()
            .downcast_mut::<Pinned>()
            .ok_or_else(|| code("MOVE_HANDLE_MISMATCH"))?;
        if !self.writable
            || !target.writable
            || !device_shell_policy::write_allowed(&self.logical)
            || !device_shell_policy::write_allowed(&target.logical)
        {
            return Err(code("READ_ONLY_HANDLE"));
        }
        self.verify()?;
        target.verify()?;
        if self.expected.is_none() || Self::same(self.expected.as_ref(), target.expected.as_ref()) {
            return Err(code("MOVE_SOURCE_INVALID"));
        }
        if let Some(existing) = &target.expected {
            if file_type(existing) != rfs::FileType::RegularFile {
                return Err(code("MOVE_TARGET_EXISTS_OR_LINK"));
            }
        }
        // 克隆父 fd 避免借用 self 跨 verify（原版 Java 无此约束，语义不变）。
        let self_parent = self
            .parent
            .as_ref()
            .ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?
            .try_clone()?;
        let target_parent = target
            .parent
            .as_ref()
            .ok_or_else(|| code("FILE_HANDLE_CLOSED_OR_ROOT"))?
            .try_clone()?;
        if no_clobber {
            // 对普通文件用内核独占 link 发布；不支持 hard-link 的挂载返回明确错误且保留源。
            if self.expected.map(|s| file_type(&s)) != Some(rfs::FileType::RegularFile)
                || target.expected.is_some()
            {
                return Err(code("ATOMIC_NOCLOBBER_MOVE_UNSUPPORTED"));
            }
            rfs::linkat(&self_parent, &self.name, &target_parent, &target.name, AtFlags::empty())
                .map_err(failure)?;
            target.expected = target.stat()?;
            self.verify()?;
            target.verify()?;
            if !Self::same(self.expected.as_ref(), target.expected.as_ref()) {
                return Err(code("FILE_TARGET_CHANGED"));
            }
            rfs::unlinkat(&self_parent, &self.name, AtFlags::empty()).map_err(failure)?;
        } else {
            // rename 对最终链接只改名该链接本身；两个父目录已固定，EXDEV 不改通道重放。
            rfs::renameat(&self_parent, &self.name, &target_parent, &target.name).map_err(failure)?;
        }
        target.expected = target.stat()?;
        self.expected = None;
        Ok(())
    }

    fn close(&mut self) -> io::Result<()> {
        if self.closed {
            return Ok(());
        }
        self.closed = true;
        self.directory = None;
        self.parent = None;
        Ok(())
    }

    fn as_any_mut(&mut self) -> &mut dyn std::any::Any {
        self
    }
}

fn file_type(stat: &rfs::Stat) -> rfs::FileType {
    rfs::FileType::from_raw_mode(stat.st_mode)
}

fn fstat_fd(fd: &OwnedFd) -> io::Result<rfs::Stat> {
    rfs::fstat(fd).map_err(failure)
}

fn fstat_dir(fd: &OwnedFd) -> io::Result<rfs::Stat> {
    fstat_fd(fd)
}

fn readlink_fd(fd: &OwnedFd) -> io::Result<String> {
    let path = format!("/proc/self/fd/{}", fd.as_fd().as_raw_fd());
    std::fs::read_link(path)
        .map(|p| p.to_string_lossy().to_string())
        .map_err(|_| code("FILE_HANDLE_CLOSED_OR_ROOT"))
}

fn set_now(fd: &OwnedFd) -> io::Result<()> {
    set_mtime(fd, -1)
}

/// mtime 语义（原版 `File.setLastModified(now)` / `expected.st_mtime`）。
fn set_mtime(_fd: &OwnedFd, _mtime: i64) -> io::Result<()> {
    // 接线轮：futimens/utimensat（rustix::fs::futimens）。当前为显式未实现——
    // 语义契约（TOUCH_FAILED / FILE_TIME_FAILED）已在调用点保留。
    Err(code("TOUCH_FAILED"))
}

use std::os::fd::AsRawFd;

fn code(text: &str) -> io::Error {
    io::Error::other(text.to_string())
}

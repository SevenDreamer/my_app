// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.{ArchiveFileBoundary,TarGzipExtractor,
// TrustedAssetFileSystem} —— 现代化重构，行为契约不变。
//! 签名资产解压权威；后代写入永不跟随既有链接。
//! 错误代号契约（逐字）：`TAR_ROOT_*`/`TAR_PARENT_LINK_OR_TYPE`/`TAR_DIRECTORY_CONFLICT`/
//! `TAR_FILE_CONFLICT`/`TAR_CREATED_FILE_TYPE`/`TAR_TRUNCATED`/`TAR_TARGET_CHANGED`/
//! `TAR_LINK_TARGET`/`TAR_LINK_ESCAPE`/`TAR_LINK_CYCLE`/`TAR_EXISTING_TARGET_LINK`/
//! `TAR_HARDLINK_SOURCE`/`TAR_SYMLINK_CONFLICT`/`TAR_LINK_FAILURE`/`TAR_DIRECTORY_MODE`/
//! `TAR_STRIP`/`TAR_DUPLICATE_PROJECTED_PATH`/`TAR_FILE_LIMIT`/`TAR_ENTRY_FAILURE`/
//! `TAR_SMALL_FILE_UNSUPPORTED`。

use crate::budget;
use crate::code_error;
use crate::control::BackupControl;
use crate::fs_identity::{Fs, Node};
use crate::legacy_tar::{self, EntryKind, Member};
use crate::limits;
use std::collections::HashSet;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

/// 小文件快路径上限（原版 `TrustedAssetFileSystem.SMALL_FILE_BYTES`）。
pub const SMALL_FILE_BYTES: i64 = 32768;

/// 出生身份来自实际打开的文件描述符，不能用打开后的路径 stat 临时认领。
pub struct CreatedFile {
    pub output: Box<dyn Write>,
    pub identity: Node,
}

/// 签名内置资产解压会话（Android 实现提供；用户备份用原文件层逐项耐久策略）。
/// 仅对签名资产启用的快路径与钉定语义；泛型路径行为等价。
pub trait TrustedAssetFs: Fs {
    fn target(&self, path: &str, create_parents: bool) -> io::Result<PathBuf>;

    /// 一次文件发布共用固定父目录身份，结束时复核名称仍绑定本次目录。
    fn file_entry(&self, _path: &str) -> io::Result<Box<dyn FnOnce()>> {
        Ok(Box::new(|| {}))
    }

    /// 在同一个已核验的描述符上写入、设置权限并同步，不能按文件名重新认领。
    fn create_with_mode(&self, file: &Path, mode: u32) -> io::Result<CreatedFile>;

    fn supports_small_files(&self) -> bool {
        false
    }

    /// 仅对缺失的短成员启用；独占创建失败不得认领名称上的其他文件。
    fn prepare_small_file(
        &self,
        _file: &Path,
        _bytes: &[u8],
        _count: usize,
        _mode: u32,
    ) -> io::Result<CreatedFile> {
        Err(code_error("TAR_SMALL_FILE_UNSUPPORTED"))
    }

    /// 限制目录权限之前完整复核本次输出及父目录，并同步所有变更目录。
    fn finish_files(&self) -> io::Result<()>;

    /// 目录权限可能禁止重新遍历；使用修改权限前持有的描述符完成同步。
    fn finish_directory_modes(&self) -> io::Result<()> {
        Ok(())
    }
}

static UNIQUE: AtomicU64 = AtomicU64::new(0);

fn unique() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{nanos:x}-{}", UNIQUE.fetch_add(1, Ordering::Relaxed))
}

/// 解压权威（原版 `ArchiveFileBoundary`）。
pub struct ArchiveFileBoundary<'a> {
    fs: &'a dyn Fs,
    trusted: Option<&'a dyn TrustedAssetFs>,
    root: PathBuf,
    identity: Node,
    copy_buffer: Vec<u8>,
    /// 延迟创建的链接成员（保序）。
    pub links: Vec<Member>,
    /// 目录 → 期望权限（保序；finish 按路径长度降序应用）。
    directories: Vec<(String, u32)>,
    control: BackupControl,
}

impl<'a> ArchiveFileBoundary<'a> {
    /// 泛型路径（原版非 Trusted 分支）。
    pub fn new(fs: &'a dyn Fs, granted: &Path) -> io::Result<Self> {
        Self::build(fs, None, granted)
    }

    /// 签名资产快路径。
    pub fn new_trusted(
        fs: &'a dyn Fs,
        trusted: &'a dyn TrustedAssetFs,
        granted: &Path,
    ) -> io::Result<Self> {
        Self::build(fs, Some(trusted), granted)
    }

    fn build(
        fs: &'a dyn Fs,
        trusted: Option<&'a dyn TrustedAssetFs>,
        granted: &Path,
    ) -> io::Result<Self> {
        if fs.stat(granted)?.kind != crate::fs_identity::FileKind::Directory {
            mkdirs(fs, granted)
                .map_err(|_| code_error(format!("TAR_ROOT_CREATE:{}", granted.display())))?;
        }
        if fs.stat(granted)?.kind != crate::fs_identity::FileKind::Directory {
            return Err(code_error(format!("TAR_ROOT_LINK:{}", granted.display())));
        }
        let root = granted.to_path_buf();
        let identity = fs.stat(&root)?;
        let boundary = ArchiveFileBoundary {
            fs,
            trusted,
            root,
            identity,
            copy_buffer: vec![0u8; 262144],
            links: Vec::new(),
            directories: Vec::new(),
            control: BackupControl::new(),
        };
        boundary.verify()?;
        Ok(boundary)
    }

    fn verify(&self) -> io::Result<()> {
        let now = self.fs.stat(&self.root)?;
        if now.kind != crate::fs_identity::FileKind::Directory
            || now.device != self.identity.device
            || now.key != self.identity.key
        {
            return Err(code_error(format!("TAR_ROOT_CHANGED:{}", self.root.display())));
        }
        Ok(())
    }

    fn target(&self, path: &str, parents: bool) -> io::Result<PathBuf> {
        budget::checkpoint()?;
        self.verify()?;
        limits::path(path)?;
        if let Some(trusted) = self.trusted {
            return trusted.target(path, parents);
        }
        let mut at = self.root.clone();
        let parts: Vec<&str> = path.split('/').collect();
        for part in &parts[..parts.len() - 1] {
            at.push(part);
            let mut n = self.fs.stat(&at)?;
            if n.kind == crate::fs_identity::FileKind::Missing && parents {
                self.fs.directory(&at)?;
                n = self.fs.stat(&at)?;
            }
            if n.kind != crate::fs_identity::FileKind::Directory {
                return Err(code_error(format!(
                    "TAR_PARENT_LINK_OR_TYPE:{path}:{part}:{}",
                    n.kind.wire()
                )));
            }
        }
        at.push(parts[parts.len() - 1]);
        Ok(at)
    }

    fn directory(&mut self, m: &Member) -> io::Result<()> {
        let out = self.target(&m.path, true)?;
        let n = self.fs.stat(&out)?;
        if n.kind == crate::fs_identity::FileKind::Missing {
            self.fs.directory(&out)?;
        } else if n.kind != crate::fs_identity::FileKind::Directory {
            return Err(code_error(format!(
                "TAR_DIRECTORY_CONFLICT:{}:{}",
                m.path,
                n.kind.wire()
            )));
        }
        self.directories.push((m.path.clone(), m.mode));
        Ok(())
    }

    fn file(&mut self, m: &Member, data: &mut dyn Read) -> io::Result<()> {
        let mut guarded = budget::guard(data);
        if let Some(trusted) = self.trusted {
            let close = trusted.file_entry(&m.path)?;
            let result = self.write_file(m, &mut guarded);
            close();
            result
        } else {
            self.write_file(m, &mut guarded)
        }
    }

    fn write_file(&mut self, m: &Member, data: &mut dyn Read) -> io::Result<()> {
        let out = self.target(&m.path, true)?;
        let before = self.fs.stat(&out)?;
        if before.kind != crate::fs_identity::FileKind::Missing
            && before.kind != crate::fs_identity::FileKind::File
        {
            return Err(code_error(format!(
                "TAR_FILE_CONFLICT:{}:{}",
                m.path,
                before.kind.wire()
            )));
        }
        // 全新候选成员以 EXCL/NOFOLLOW 独占创建，失败只删除本次 inode。
        // 已有成员仍使用 staged + previous 回切，不能截断原件来节省改名。
        let fresh = before.kind == crate::fs_identity::FileKind::Missing;
        let staged = if fresh {
            out.clone()
        } else {
            out.parent()
                .unwrap_or(Path::new("."))
                .join(format!(".dsha-tar-part-{}", unique()))
        };
        let mut owned: Option<Node> = None;
        let mut published = false;
        let result = (|| -> io::Result<()> {
            let small = fresh
                && m.size >= 0
                && m.size <= SMALL_FILE_BYTES
                && self.trusted.map(|t| t.supports_small_files()).unwrap_or(false);
            let small_bytes = if small {
                self.read_small_file(m, data)?
            } else {
                0
            };
            let mut opened: Box<dyn Write> = if small {
                let trusted = self.trusted.expect("small path requires trusted fs");
                let created = trusted.prepare_small_file(&staged, &self.copy_buffer, small_bytes, m.mode)?;
                owned = Some(created.identity);
                created.output
            } else if let Some(trusted) = self.trusted {
                let created = trusted.create_with_mode(&staged, m.mode)?;
                owned = Some(created.identity);
                created.output
            } else {
                self.fs.create(&staged)?
            };
            if owned.is_none() {
                owned = Some(self.fs.stat(&staged)?);
            }
            let owned_node = owned.clone().expect("owned identity");
            if owned_node.kind != crate::fs_identity::FileKind::File {
                return Err(code_error(format!("TAR_CREATED_FILE_TYPE:{}", m.path)));
            }
            if !small {
                let mut bytes: i64 = 0;
                loop {
                    let n = data.read(&mut self.copy_buffer)?;
                    if n == 0 {
                        break;
                    }
                    bytes = limits::add(bytes, n as i64, m.size)?;
                    opened.write_all(&self.copy_buffer[..n])?;
                }
                if bytes != m.size {
                    return Err(code_error(format!("TAR_TRUNCATED:{}", m.path)));
                }
            }
            drop(opened);
            self.verify()?;
            if before.kind == crate::fs_identity::FileKind::File {
                if !before.same(&self.fs.stat(&out)?) {
                    return Err(code_error(format!("TAR_TARGET_CHANGED:{}", m.path)));
                }
                let previous = out
                    .parent()
                    .unwrap_or(Path::new("."))
                    .join(format!(".dsha-tar-previous-{}", unique()));
                self.fs.move_path(&out, &previous)?;
                if let Err(error) = self.fs.move_path(&staged, &out) {
                    if self.fs.stat(&out)?.kind == crate::fs_identity::FileKind::Missing {
                        self.fs.move_path(&previous, &out)?;
                    }
                    return Err(error);
                }
                self.fs.delete(&previous)?;
            } else {
                let now = self.fs.stat(&out)?;
                if now.kind != crate::fs_identity::FileKind::File
                    || now.device != owned_node.device
                    || now.key != owned_node.key
                {
                    return Err(code_error(format!("TAR_TARGET_CHANGED:{}", m.path)));
                }
            }
            if self.trusted.is_none() {
                self.fs.mode(&out, m.mode)?;
            }
            self.fs.sync_directory(out.parent().unwrap_or(Path::new(".")))?;
            self.verify()?;
            published = true;
            Ok(())
        })();
        if !published {
            if let Some(owned_node) = &owned {
                if let Ok(remaining) = self.fs.stat(&staged) {
                    if remaining.kind == crate::fs_identity::FileKind::File
                        && remaining.device == owned_node.device
                        && remaining.key == owned_node.key
                    {
                        let _ = self.fs.delete(&staged);
                    }
                }
            }
        }
        result
    }

    /// 多留一个字节沿用正文预算检查；共享提取缓冲，不为每个短成员分配数组。
    fn read_small_file(&mut self, m: &Member, data: &mut dyn Read) -> io::Result<usize> {
        let mut bytes = 0usize;
        loop {
            let want = (m.size + 1 - bytes as i64) as usize;
            let n = data.read(&mut self.copy_buffer[bytes..bytes + want])?;
            self.control.check()?;
            if n == 0 {
                break;
            }
            bytes = limits::add(bytes as i64, n as i64, m.size)? as usize;
        }
        if bytes as i64 != m.size {
            return Err(code_error(format!("TAR_TRUNCATED:{}", m.path)));
        }
        self.control.check()?;
        Ok(bytes)
    }

    /// 链接目标解析：防逃逸（TAR_LINK_ESCAPE）/ 跳数上限 40（TAR_LINK_CYCLE）/
    /// 既有链接碰撞（TAR_EXISTING_TARGET_LINK）。
    fn resolve(&self, name: &str, raw: &str, hard: bool) -> io::Result<String> {
        if raw.is_empty() || raw.contains('\\') || raw.contains('\0') {
            return Err(code_error(format!("TAR_LINK_TARGET:{name}")));
        }
        let parent = if hard {
            ""
        } else {
            match name.rfind('/') {
                Some(slash) => &name[..slash],
                None => "",
            }
        };
        let mut pending: Vec<String> = Vec::new();
        let mut stack: Vec<String> = Vec::new();
        if !raw.starts_with('/') && !parent.is_empty() {
            for part in parent.split('/') {
                stack.push(part.to_string());
            }
        }
        for part in raw.split('/').rev() {
            pending.push(part.to_string()); // 头插等价：反转压入后从尾弹出
        }
        let mut hops = 0;
        while let Some(part) = pending.pop() {
            if part.is_empty() || part == "." {
                continue;
            }
            if part == ".." {
                if stack.is_empty() {
                    return Err(code_error(format!("TAR_LINK_ESCAPE:{name}")));
                }
                stack.pop();
                continue;
            }
            stack.push(part);
            let candidate = stack.join("/");
            let link = self.links.iter().find(|l| l.path == candidate).cloned();
            if let Some(link) = link {
                hops += 1;
                if hops > 40 {
                    return Err(code_error(format!("TAR_LINK_CYCLE:{name}")));
                }
                stack.pop();
                if link.kind == EntryKind::Hardlink || link.target.starts_with('/') {
                    stack.clear();
                }
                for part in link.target.split('/').rev() {
                    pending.push(part.to_string());
                }
            } else if self
                .fs
                .stat(&self.root.join(&candidate))?
                .kind
                == crate::fs_identity::FileKind::Link
            {
                return Err(code_error(format!(
                    "TAR_EXISTING_TARGET_LINK:{name}:{candidate}"
                )));
            }
        }
        Ok(stack.join("/"))
    }

    fn finish(&mut self) -> io::Result<()> {
        for link in &self.links {
            budget::checkpoint()?;
            self.control.check()?;
            self.resolve(&link.path, &link.target, link.kind == EntryKind::Hardlink)?;
        }
        let links = self.links.clone();
        for link in &links {
            let outcome = (|| -> io::Result<()> {
                self.control.check()?;
                let out = self.target(&link.path, true)?;
                let resolved =
                    self.resolve(&link.path, &link.target, link.kind == EntryKind::Hardlink)?;
                let to = if resolved.is_empty() {
                    self.root.clone()
                } else {
                    self.root.join(&resolved)
                };
                let existing = self.fs.stat(&out)?;
                if link.kind == EntryKind::Hardlink {
                    let source = self.fs.stat(&to)?;
                    if source.kind != crate::fs_identity::FileKind::File {
                        return Err(code_error(format!(
                            "TAR_HARDLINK_SOURCE:{}:{}",
                            link.path,
                            source.kind.wire()
                        )));
                    }
                    let mut data = self.fs.read_file(&to, &source)?;
                    let copy = Member {
                        path: link.path.clone(),
                        kind: EntryKind::File,
                        target: String::new(),
                        size: source.size as i64,
                        mode: link.mode,
                    };
                    self.file(&copy, data.as_mut())
                } else {
                    // 校验最终位置，但保留链接间接层：把 next -> current -> tool
                    // 拍平会破坏之后合法的 current 更新。
                    let mut relative = link.target.clone();
                    if relative.starts_with('/') {
                        let depth = link.path.split('/').count() - 1;
                        let guest_root = "../".repeat(depth);
                        while relative.starts_with('/') {
                            relative.remove(0);
                        }
                        relative = format!("{guest_root}{}", if relative.is_empty() { "." } else { &relative });
                    }
                    if existing.kind == crate::fs_identity::FileKind::Link {
                        let old = self.fs.read_link(&out)?;
                        if old.starts_with('/')
                            || self.resolve(&link.path, &old, false)? != resolved
                        {
                            return Err(code_error(format!(
                                "TAR_SYMLINK_CONFLICT:{}",
                                link.path
                            )));
                        }
                    } else if existing.kind == crate::fs_identity::FileKind::Missing {
                        self.fs.symlink(&relative, &out)?;
                    } else {
                        return Err(code_error(format!(
                            "TAR_SYMLINK_CONFLICT:{}:{}",
                            link.path,
                            existing.kind.wire()
                        )));
                    }
                    Ok(())
                }
            })();
            if let Err(error) = outcome {
                return Err(code_error(format!(
                    "TAR_LINK_FAILURE:{}:{}:{}",
                    link.path,
                    link.kind.wire(),
                    error
                )));
            }
        }
        if let Some(trusted) = self.trusted {
            trusted.finish_files()?;
        }
        let mut paths: Vec<(String, u32)> = self.directories.clone();
        paths.sort_by(|a, b| b.0.len().cmp(&a.0.len()));
        for (path, mode) in paths {
            let outcome = self.control.check().and_then(|_| {
                let at = self.target(&path, false)?;
                self.fs.mode(&at, mode)
            });
            if let Err(error) = outcome {
                return Err(code_error(format!("TAR_DIRECTORY_MODE:{path}:{error}")));
            }
        }
        self.control.check()?;
        if let Some(trusted) = self.trusted {
            trusted.finish_directory_modes()?;
        }
        self.verify()
    }
}

fn mkdirs(fs: &dyn Fs, path: &Path) -> io::Result<()> {
    let mut current = PathBuf::new();
    for part in path.components() {
        current.push(part);
        if fs.stat(&current)?.kind == crate::fs_identity::FileKind::Missing {
            fs.directory(&current)?;
        }
    }
    Ok(())
}

// ── TarGzipExtractor 等价入口 ──────────────────────────────────────────

struct ExtractVisitor<'a, 'b> {
    boundary: &'a mut ArchiveFileBoundary<'b>,
    strip: usize,
    projected: &'a mut HashSet<String>,
    selected: &'a dyn Fn(&str) -> bool,
}

impl legacy_tar::Visitor for ExtractVisitor<'_, '_> {
    fn entry(&mut self, m: &Member, data: &mut dyn Read) -> io::Result<()> {
        budget::checkpoint()?;
        let mut path = m.path.clone();
        for _ in 0..self.strip {
            path = match path.find('/') {
                Some(slash) => path[slash + 1..].to_string(),
                None => String::new(),
            };
        }
        if path.is_empty() || !(self.selected)(&path) {
            return Ok(());
        }
        if !self.projected.insert(path.clone()) {
            return Err(code_error(format!(
                "TAR_DUPLICATE_PROJECTED_PATH:{path}"
            )));
        }
        let mut link = m.target.clone();
        if m.kind == EntryKind::Hardlink {
            for _ in 0..self.strip {
                link = match link.find('/') {
                    Some(slash) => link[slash + 1..].to_string(),
                    None => String::new(),
                };
            }
        }
        let target =
            Member { path: path.clone(), kind: m.kind, target: link, size: m.size, mode: m.mode };
        let outcome = match target.kind {
            EntryKind::File => {
                if target.size > 8 * 1024 * 1024 * 1024 {
                    return Err(code_error("TAR_FILE_LIMIT"));
                }
                self.boundary.file(&target, data)
            }
            EntryKind::Directory => self.boundary.directory(&target),
            _ => {
                self.boundary.links.push(target.clone());
                Ok(())
            }
        };
        outcome.map_err(|error| {
            code_error(format!(
                "TAR_ENTRY_FAILURE:{}:{}:{}",
                path,
                target.kind.wire(),
                error
            ))
        })
    }
}

/// 压缩包解包入口（原版 `TarGzipExtractor.extractSelected`）；返回本次投影路径集。
pub fn extract_selected(
    input: &mut dyn Read,
    dest: &Path,
    strip: usize,
    selected: &dyn Fn(&str) -> bool,
    fs: &dyn Fs,
) -> io::Result<HashSet<String>> {
    if strip > 64 {
        return Err(code_error("TAR_STRIP"));
    }
    budget::checkpoint()?;
    let mut boundary = ArchiveFileBoundary::new(fs, dest)?;
    let control = BackupControl::new();
    let mut projected: HashSet<String> = HashSet::new();
    {
        let mut guarded = budget::guard(input);
        let mut visitor =
            ExtractVisitor { boundary: &mut boundary, strip, projected: &mut projected, selected };
        legacy_tar::read_trusted_assets(&mut guarded, &mut visitor, &control)?;
    }
    boundary.finish()?;
    budget::checkpoint()?;
    Ok(projected)
}

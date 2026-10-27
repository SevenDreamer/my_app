// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.ColdSplitExtraction —— 现代化重构，行为契约不变。
//! 只在已授予的全新冷候选内并行；两个写入会话全部退出后才组装签名树。
//!
//! 错误代号契约（逐字）：`COLD_SPLIT_ROOT_SCOPE`/`COLD_SPLIT_ROOT_EXISTS`/
//! `COLD_SPLIT_CONTRACT`/`COLD_SPLIT_BASE_MODULES`/`COLD_SPLIT_REQUIRED_FILE:<path>`/
//! `COLD_SPLIT_SCAFFOLD:<path>`/`COLD_SPLIT_DIRECTORY_MODE:<path>`/`COLD_SPLIT_NPM_CONFLICT`/
//! `COLD_SPLIT_TARGET_CONFLICT:<path>`/`COLD_SPLIT_MODULES_NOT_EMPTY`/
//! `COLD_SPLIT_RETAINED_MEMBER:<path>`/`COLD_SPLIT_RUNTIME_MEMBER:<path>`/
//! `COLD_SPLIT_LINK`/`COLD_SPLIT_LINK_ESCAPE`/`COLD_SPLIT_MOVE_CHANGED:<path>`/
//! `COLD_SPLIT_EXTRACTION`/`CANCELLED`（身份比对 `COLD_SPLIT_ROOT_CHANGED` 在 fs_identity）。

use crate::archive;
use crate::code_error;
use crate::control::BackupControl;
use crate::fs_identity::{self, Fs, FileKind, Node, same_identity};
use crate::signed_members::SignedAssetMembers;
use std::collections::BTreeSet;
use std::io::{self, Read};
use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::Mutex;

const MODULES: &str = "usr/local/lib/node_modules";
const DSH: &str = "usr/local/lib/node_modules/@deepseek-ai/dsh";
const BIN: &str = "usr/local/bin";
const SHARE: &str = "usr/local/share";
const VERSION: &str = "usr/local/share/dsha/dsh-runtime.version";
const SCAFFOLD: [&str; 6] = ["", "usr", "usr/local", "usr/local/lib", BIN, SHARE];

/// 双流解包器（原版 `Extractor`：输入流 → 本次成员路径集）。
pub type Extractor = dyn Fn(&mut dyn Read, &Path) -> io::Result<BTreeSet<String>> + Sync;

/// 签名分包直解（原版 `extractSigned`）；Android 的 signedMember 登记由接线层补。
pub fn extract_signed(
    input: &mut dyn Read,
    root: &Path,
    fs: &dyn Fs,
) -> io::Result<BTreeSet<String>> {
    let projected = archive::extract_selected(input, root, 0, &|_| true, fs)?;
    Ok(projected.into_iter().collect())
}

/// 双流并行解包 + 签名树组装（原版 `run`）。
/// [base_input] 解到 [base]（scaffold），[runtime_input] 解到运行时候选；
/// 两个 Worker 全部退出后才组装。[progress] 回报 (已读字节, 总字节)。
pub fn run(
    fs: &(dyn Fs + Sync),
    base: &Path,
    operation: &Path,
    base_input: &mut (dyn Read + Send),
    runtime_input: &mut (dyn Read + Send),
    total: i64,
    progress: &(dyn Fn(i64, i64) + Sync),
    extractor: &Extractor,
) -> io::Result<()> {
    let control = BackupControl::new();
    control.check()?;
    let base_identity = fs.stat(base)?;
    let operation_identity = fs.stat(operation)?;
    if base_identity.kind != FileKind::Directory
        || operation_identity.kind != FileKind::Directory
        || base_identity.device != operation_identity.device
        || !fs.list(base)?.is_empty()
    {
        return Err(code_error("COLD_SPLIT_ROOT_SCOPE"));
    }
    let runtime = operation.join(format!("split-dsh-{}", crate::unique_name()));
    if fs.stat(&runtime)?.kind != FileKind::Missing {
        return Err(code_error("COLD_SPLIT_ROOT_EXISTS"));
    }
    fs.directory(&runtime)?;
    let runtime_identity = fs.stat(&runtime)?;
    if runtime_identity.kind != FileKind::Directory
        || runtime_identity.device != base_identity.device
    {
        return Err(code_error("COLD_SPLIT_ROOT_SCOPE"));
    }

    let read = Arc::new(AtomicI64::new(0));
    let first_result = Arc::new(Mutex::new(None));
    let second_result = Arc::new(Mutex::new(None));
    let runtime_path: &Path = &runtime;
    std::thread::scope(|scope| {
        let mut base_input = CountingRead { inner: base_input, read: &read };
        let mut runtime_input = CountingRead { inner: runtime_input, read: &read };
        let first = {
            let first_result = Arc::clone(&first_result);
            scope.spawn(move || {
                let outcome = extractor(&mut base_input, base);
                *first_result.lock().unwrap() = Some(outcome);
            })
        };
        let second = {
            let second_result = Arc::clone(&second_result);
            scope.spawn(move || {
                let outcome = extractor(&mut runtime_input, runtime_path);
                *second_result.lock().unwrap() = Some(outcome);
            })
        };
        // 进度泵：任一失败即让 scope 退出后 join 收尸（Rust 无外部中断，
        // 保持"等待全部退出后才组装"的硬语义）。
        loop {
            if first.is_finished() && second.is_finished() {
                break;
            }
            progress(read.load(Ordering::SeqCst), total);
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        progress(read.load(Ordering::SeqCst), total);
    });

    let first_outcome = first_result.lock().unwrap().take();
    let second_outcome = second_result.lock().unwrap().take();
    let base_paths = match first_outcome {
        Some(Ok(paths)) => paths,
        Some(Err(error)) => return Err(error),
        None => return Err(code_error("COLD_SPLIT_EXTRACTION")),
    };
    let runtime_paths = match second_outcome {
        Some(Ok(paths)) => paths,
        Some(Err(error)) => return Err(error),
        None => return Err(code_error("COLD_SPLIT_EXTRACTION")),
    };
    fs_identity::require_identity(fs, operation, &operation_identity)?;
    assemble(
        fs,
        base,
        &base_identity,
        &runtime,
        &runtime_identity,
        &base_paths,
        &runtime_paths,
    )
}

struct CountingRead<'a> {
    inner: &'a mut (dyn Read + Send),
    read: &'a AtomicI64,
}

impl Read for CountingRead<'_> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let n = self.inner.read(buf)?;
        if n > 0 {
            self.read.fetch_add(n as i64, Ordering::SeqCst);
        }
        Ok(n)
    }
}

/// 签名树组装（原版 `assemble`）：逐身份核验 + 原子移动 + scaffold 清场。
pub fn assemble(
    fs: &(dyn Fs + Sync),
    base: &Path,
    base_identity: &Node,
    runtime: &Path,
    runtime_identity: &Node,
    base_paths: &BTreeSet<String>,
    runtime_paths: &BTreeSet<String>,
) -> io::Result<()> {
    let control = BackupControl::new();
    control.check()?;
    fs_identity::require_identity(fs, base, base_identity)?;
    fs_identity::require_identity(fs, runtime, runtime_identity)?;
    let base_members = SignedAssetMembers::new(base_paths.iter().map(|s| s.as_str()))?;
    let runtime_members = SignedAssetMembers::new(runtime_paths.iter().map(|s| s.as_str()))?;
    if base_members.names(MODULES) != BTreeSet::from(["npm".to_string()])
        || runtime_members.names(MODULES).contains("npm")
        || !runtime_paths.contains(&format!("{DSH}/lib/bin.js"))
        || !runtime_paths.contains(VERSION)
        || !runtime_paths.contains(&format!("{BIN}/dsh"))
    {
        return Err(code_error("COLD_SPLIT_CONTRACT"));
    }
    for path in base_paths {
        if path.starts_with(&format!("{MODULES}/"))
            && path != &format!("{MODULES}/npm")
            && !path.starts_with(&format!("{MODULES}/npm/"))
        {
            return Err(code_error("COLD_SPLIT_BASE_MODULES"));
        }
    }
    for path in runtime_paths {
        verify_runtime_member(fs, runtime, path, &runtime_members)?;
    }
    for path in [format!("{DSH}/lib/bin.js"), VERSION.to_string()] {
        let node = fs.stat(&runtime.join(&path))?;
        if node.kind != FileKind::File || node.size == 0 {
            return Err(code_error(format!("COLD_SPLIT_REQUIRED_FILE:{path}")));
        }
    }
    let mut scaffold: Vec<(String, Node)> = Vec::new();
    for path in SCAFFOLD {
        control.check()?;
        let to = if path.is_empty() { runtime.to_path_buf() } else { runtime.join(path) };
        let node = fs.stat(&to)?;
        if node.kind != FileKind::Directory {
            return Err(code_error(format!("COLD_SPLIT_SCAFFOLD:{path}")));
        }
        runtime_members.verify(path, &fs.list(&to)?)?;
        let old = if path.is_empty() { base.to_path_buf() } else { base.join(path) };
        let before = fs.stat(&old)?;
        if before.kind != FileKind::Directory || before.mode != node.mode {
            return Err(code_error(format!("COLD_SPLIT_DIRECTORY_MODE:{path}")));
        }
        scaffold.push((path.to_string(), node));
    }
    let old_modules = base.join(MODULES);
    let new_modules = runtime.join(MODULES);
    let old_modules_identity = fs.stat(&old_modules)?;
    let new_modules_identity = fs.stat(&new_modules)?;
    if old_modules_identity.kind != FileKind::Directory
        || new_modules_identity.kind != FileKind::Directory
        || old_modules_identity.mode != new_modules_identity.mode
    {
        return Err(code_error(format!("COLD_SPLIT_DIRECTORY_MODE:{MODULES}")));
    }
    base_members.verify(MODULES, &fs.list(&old_modules)?)?;
    runtime_members.verify(MODULES, &fs.list(&new_modules)?)?;
    fs.list(&old_modules.join("npm"))?;
    let mut leaves: Vec<String> = Vec::new();
    for name in runtime_members.names(BIN) {
        leaves.push(format!("{BIN}/{name}"));
    }
    for name in runtime_members.names(SHARE) {
        leaves.push(format!("{SHARE}/{name}"));
    }
    let mut sources: Vec<(String, Node)> = Vec::new();
    for path in &leaves {
        let source = runtime.join(path);
        let target = base.join(path);
        let node = fs.stat(&source)?;
        let expected = if path.starts_with(&format!("{BIN}/")) {
            FileKind::Link
        } else {
            FileKind::Directory
        };
        if node.kind != expected || fs.stat(&target)?.kind != FileKind::Missing {
            return Err(code_error(format!("COLD_SPLIT_TARGET_CONFLICT:{path}")));
        }
        sources.push((path.clone(), node));
    }
    let npm = old_modules.join("npm");
    let staged_npm = new_modules.join("npm");
    let npm_identity = fs.stat(&npm)?;
    if npm_identity.kind != FileKind::Directory
        || fs.stat(&staged_npm)?.kind != FileKind::Missing
    {
        return Err(code_error("COLD_SPLIT_NPM_CONFLICT"));
    }
    move_path(fs, &npm, &staged_npm, &npm_identity, &control)?;
    fs_identity::require_identity(fs, &old_modules, &old_modules_identity)?;
    if !fs.list(&old_modules)?.is_empty() {
        return Err(code_error("COLD_SPLIT_MODULES_NOT_EMPTY"));
    }
    fs.delete(&old_modules)?;
    fs.sync_directory(old_modules.parent().unwrap_or(Path::new(".")))?;
    move_path(fs, &new_modules, &old_modules, &new_modules_identity, &control)?;
    for (path, node) in &sources {
        move_path(fs, &runtime.join(path), &base.join(path), node, &control)?;
    }
    fs_identity::require_identity(fs, base, base_identity)?;
    fs_identity::require_identity(fs, runtime, runtime_identity)?;
    let mut empty: Vec<(String, Node)> = scaffold.clone();
    empty.sort_by(|a, b| b.0.len().cmp(&a.0.len()));
    for (path, node) in &empty {
        control.check()?;
        let at = if path.is_empty() { runtime.to_path_buf() } else { runtime.join(path) };
        fs_identity::require_identity(fs, &at, node)?;
        if !fs.list(&at)?.is_empty() {
            return Err(code_error(format!("COLD_SPLIT_RETAINED_MEMBER:{path}")));
        }
        fs.delete(&at)?;
        fs.sync_directory(at.parent().unwrap_or(Path::new(".")))?;
    }
    fs_identity::require_identity(fs, base, base_identity)?;
    Ok(())
}

/// 运行时成员白名单（原版 `verifyRuntimeMember`）。
fn verify_runtime_member(
    fs: &dyn Fs,
    root: &Path,
    path: &str,
    members: &SignedAssetMembers,
) -> io::Result<()> {
    crate::limits::path(path)?;
    if path.starts_with(&format!("{DSH}/")) {
        return Ok(());
    }
    let node = fs.stat(&root.join(path))?;
    if node.kind == FileKind::Directory {
        if path == DSH
            || SCAFFOLD.contains(&path)
            || path == MODULES
            || path == format!("{SHARE}/dsha")
        {
            return Ok(());
        }
        if let Some(name) = path.strip_prefix(&format!("{MODULES}/")) {
            if scoped_scope(name) && !members.names(path).is_empty() {
                return Ok(());
            }
        }
    }
    if path == VERSION && node.kind == FileKind::File {
        return Ok(());
    }
    if [format!("{BIN}/dsh"), format!("{BIN}/tsc"), format!("{BIN}/tsserver")].contains(&path.to_string())
        && node.kind == FileKind::Link
        && resolved(path, &fs.read_link(&root.join(path))?)?.starts_with(&format!("{DSH}/"))
    {
        return Ok(());
    }
    if path.starts_with(&format!("{MODULES}/")) {
        let name = &path[MODULES.len() + 1..];
        if name != "npm"
            && name != "@deepseek-ai/dsh"
            && package_name(name)
            && node.kind == FileKind::Link
            && resolved(path, &fs.read_link(&root.join(path))?)?
                .starts_with(&format!("{DSH}/node_modules/"))
        {
            return Ok(());
        }
    }
    Err(code_error(format!("COLD_SPLIT_RUNTIME_MEMBER:{path}")))
}

/// `@[a-z0-9][a-z0-9._-]*`（scope 目录名）。
fn scoped_scope(name: &str) -> bool {
    let inner = match name.strip_prefix('@') {
        Some(inner) => inner,
        None => return false,
    };
    match inner.split_once('/') {
        Some((scope, "")) => scoped_part(scope),
        Some(_) => false,
        None => scoped_part(inner),
    }
}

fn scoped_part(part: &str) -> bool {
    let mut chars = part.chars();
    match chars.next() {
        Some(c) if c.is_ascii_lowercase() || c.is_ascii_digit() => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, '.' | '_' | '-'))
}

/// `(?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*`。
fn package_name(name: &str) -> bool {
    match name.split_once('/') {
        Some((scope, rest)) => scoped_part(scope) && scoped_part(rest),
        None => scoped_part(name),
    }
}

/// 链接目标解析（防逃逸；原版 `resolved`）。
fn resolved(name: &str, target: &str) -> io::Result<String> {
    if target.is_empty() || target.contains('\\') || target.contains('\0') {
        return Err(code_error("COLD_SPLIT_LINK"));
    }
    let mut parts: Vec<&str> = Vec::new();
    if !target.starts_with('/') {
        let parent = &name[..name.rfind('/').map(|s| s).unwrap_or(0)];
        if !parent.is_empty() {
            parts.extend(parent.split('/'));
        }
    }
    for part in target.split('/') {
        if part.is_empty() || part == "." {
            continue;
        }
        if part == ".." {
            if parts.is_empty() {
                return Err(code_error("COLD_SPLIT_LINK_ESCAPE"));
            }
            parts.pop();
        } else {
            parts.push(part);
        }
    }
    Ok(parts.join("/"))
}

/// 原子移动（原版 `move`）：前后身份核验 + 双目录 fsync。
fn move_path(
    fs: &dyn Fs,
    from: &Path,
    to: &Path,
    expected: &Node,
    control: &BackupControl,
) -> io::Result<()> {
    control.check()?;
    let before = fs.stat(from)?;
    if !same_identity(expected, &before)
        || expected.mode != before.mode
        || fs.stat(to)?.kind != FileKind::Missing
    {
        return Err(code_error(format!(
            "COLD_SPLIT_MOVE_CHANGED:{}",
            from.display()
        )));
    }
    fs.move_path(from, to)?;
    let after = fs.stat(to)?;
    if !same_identity(expected, &after)
        || expected.mode != after.mode
        || fs.stat(from)?.kind != FileKind::Missing
    {
        return Err(code_error(format!(
            "COLD_SPLIT_MOVE_CHANGED:{}",
            to.display()
        )));
    }
    fs.sync_directory(from.parent().unwrap_or(Path::new(".")))?;
    fs.sync_directory(to.parent().unwrap_or(Path::new(".")))?;
    Ok(())
}

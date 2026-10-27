// 版权来源：DSHA（MIT）com.deepseekharness.app.util.DeviceFileOperations —— 现代化重构，行为契约不变。
//! 受管设备文件动作；目录句柄由平台层固定，不能检查完后重新交给 shell 解析路径。
//! 没有 cp/mv/rm 子进程或沿用户链接回退。
//!
//! 错误代号契约（逐字）：`FILE_PLAN_REQUIRED`/`FILE_OPERATION_CANCELLED`/
//! `LINK_OR_SPECIAL_FILE`/`DESTINATION_DIRECTORY_REQUIRED`/`SELF_OR_DESCENDANT_TARGET`/
//! `RECURSIVE_COPY_REQUIRED`/`RECURSIVE_DELETE_REQUIRED`/`FILE_MISSING`/
//! `FILE_OPERATION_LIMIT`/`FILE_OPERATION_UNSUPPORTED`/`PROTECTED_WRITE_PATH`。

use std::cell::Cell;
use std::io::{self, Read, Write};

thread_local! {
    /// 线程中断态（原版 `Thread.currentThread().isInterrupted()` 的移植面）。
    static CANCELLED: Cell<bool> = const { Cell::new(false) };
}

/// 请求取消当前线程的文件操作。
pub fn set_cancelled(value: bool) {
    CANCELLED.with(|c| c.set(value));
}

/// 取消检查（`FILE_OPERATION_CANCELLED`，中断语义）。
pub fn cancelled() -> io::Result<()> {
    if CANCELLED.with(|c| c.get()) {
        return Err(io::Error::new(io::ErrorKind::Interrupted, "FILE_OPERATION_CANCELLED"));
    }
    Ok(())
}

/// 文件计划（原版 `DeviceShellPolicy.Plan` 的 FILE 面；策略层构造/校验见后续移植）。
#[derive(Debug, Clone)]
pub struct FilePlan {
    pub kind: &'static str,
    pub argv: Vec<String>,
    pub operands: Vec<String>,
}

impl FilePlan {
    pub fn command(&self) -> &str {
        self.argv.first().map(|s| s.as_str()).unwrap_or("")
    }
}

/// 策略面（原版 `DeviceShellPolicy` 静态面；实现随策略模型轮移植）。
pub trait DevicePolicy {
    fn normalize(&self, raw: &str) -> io::Result<String>;
    fn write_allowed(&self, path: &str) -> bool;
}

/// 设备文件入口（原版 `DeviceFileOperations.Access`）。
pub trait Access {
    fn open(&self, path: &str, write: bool, parents: bool) -> io::Result<Box<dyn Entry>>;
    fn validate(&self, path: &str, write: bool, parents: bool) -> io::Result<()>;
}

/// 固定句柄条目（原版 `Entry`；`close` 显式释放，Drop 兜底）。
pub trait Entry {
    fn path(&self) -> &str;
    fn name(&self) -> &str;
    fn entry_type(&mut self) -> io::Result<String>;
    fn child(&mut self, name: &str) -> io::Result<Box<dyn Entry>>;
    fn names(&mut self) -> io::Result<Vec<String>>;
    fn read(&mut self) -> io::Result<Box<dyn Read>>;
    fn write(&mut self) -> io::Result<Box<dyn Write>>;
    fn make_directory(&mut self) -> io::Result<()>;
    fn touch(&mut self) -> io::Result<()>;
    fn metadata_to(&mut self, target: &mut dyn Entry) -> io::Result<()>;
    fn delete(&mut self) -> io::Result<()>;
    fn move_to(&mut self, target: &mut dyn Entry, no_clobber: bool) -> io::Result<()>;
    fn close(&mut self) -> io::Result<()>;

    /// 具体型出口（原版 `instanceof Pinned` 的 downcast 面）。
    fn as_any_mut(&mut self) -> &mut dyn std::any::Any;
}

/// 执行 FILE 计划（原版 `DeviceFileOperations.execute`）。
pub fn execute(
    plan: &FilePlan,
    policy: &dyn DevicePolicy,
    access: &dyn Access,
) -> io::Result<()> {
    if plan.kind != "FILE" {
        return Err(code("FILE_PLAN_REQUIRED"));
    }
    cancelled()?;
    let op = plan.command().to_string();
    // 先拒绝整批已知链接/特殊节点；执行期间仍由已打开的目录句柄再次核对。
    for (i, operand) in plan.operands.iter().enumerate() {
        access.validate(
            operand,
            !(op == "cp" && i + 1 < plan.operands.len()),
            op == "mkdir" && flag(plan, 'p'),
        )?;
    }
    if op == "cp" || op == "mv" {
        preflight_transfers(plan, access)?;
        let mut destination = access.open(plan.operands.last().unwrap(), true, false)?;
        let directory = destination.entry_type()? == "DIRECTORY";
        if plan.operands.len() > 2 && !directory {
            return Err(code("DESTINATION_DIRECTORY_REQUIRED"));
        }
        for operand in &plan.operands[..plan.operands.len() - 1] {
            cancelled()?;
            let mut source = access.open(operand, op == "mv", false)?;
            if directory {
                let mut target = destination.child(source.name())?;
                transfer(policy, plan, source.as_mut(), target.as_mut())?;
            } else {
                transfer(policy, plan, source.as_mut(), destination.as_mut())?;
            }
        }
        return Ok(());
    }
    if op == "rm" || op == "rmdir" {
        for path in &plan.operands {
            let mut entry = access.open(path, true, false)?;
            if entry.entry_type()? == "DIRECTORY" {
                let mut count = 0;
                inspect(entry.as_mut(), &mut count, 0)?;
            }
        }
    }
    for path in &plan.operands {
        cancelled()?;
        let mut target = access.open(path, true, op == "mkdir" && flag(plan, 'p'))?;
        match op.as_str() {
            "mkdir" => {
                if !(flag(plan, 'p') && target.entry_type()? == "DIRECTORY") {
                    target.make_directory()?;
                }
            }
            "touch" => {
                if !(flag(plan, 'c') && target.entry_type()? == "MISSING") {
                    target.touch()?;
                }
            }
            "rm" => {
                if target.entry_type()? == "DIRECTORY" {
                    let mut count = 0;
                    inspect(target.as_mut(), &mut count, 0)?;
                }
                if flag(plan, 'd')
                    && !flag(plan, 'r')
                    && !flag(plan, 'R')
                    && target.entry_type()? == "DIRECTORY"
                {
                    target.delete()?;
                    continue;
                }
                let mut count = 0;
                remove(
                    target.as_mut(),
                    flag(plan, 'r') || flag(plan, 'R'),
                    flag(plan, 'f'),
                    &mut count,
                    0,
                )?;
            }
            "rmdir" => {
                if target.entry_type()? != "DIRECTORY" {
                    return Err(code("DIRECTORY_REQUIRED"));
                }
                target.delete()?;
            }
            _ => return Err(code("FILE_OPERATION_UNSUPPORTED")),
        }
    }
    Ok(())
}

fn preflight_transfers(plan: &FilePlan, access: &dyn Access) -> io::Result<()> {
    let mut destination = access.open(plan.operands.last().unwrap(), true, false)?;
    let directory = destination.entry_type()? == "DIRECTORY";
    if plan.operands.len() > 2 && !directory {
        return Err(code("DESTINATION_DIRECTORY_REQUIRED"));
    }
    for operand in &plan.operands[..plan.operands.len() - 1] {
        let mut source = access.open(operand, plan.command() == "mv", false)?;
        let mut count = 0;
        inspect(source.as_mut(), &mut count, 0)?;
        if directory {
            let mut target = destination.child(source.name())?;
            let kind = target.entry_type()?;
            if kind == "DIRECTORY" {
                let mut count = 0;
                inspect(target.as_mut(), &mut count, 0)?;
            } else if kind != "FILE" && kind != "MISSING" {
                return Err(code("LINK_OR_SPECIAL_FILE"));
            }
        }
    }
    Ok(())
}

fn transfer(
    policy: &dyn DevicePolicy,
    plan: &FilePlan,
    source: &mut dyn Entry,
    target: &mut dyn Entry,
) -> io::Result<()> {
    let from = policy.normalize(source.path())?;
    let to = policy.normalize(target.path())?;
    if from == to || to.starts_with(&format!("{from}/")) {
        return Err(code("SELF_OR_DESCENDANT_TARGET"));
    }
    if flag(plan, 'n') && target.entry_type()? != "MISSING" {
        return Ok(());
    }
    if plan.command() == "mv" {
        let mut count = 0;
        inspect(source, &mut count, 0)?;
        cancelled()?;
        source.move_to(target, flag(plan, 'n'))
    } else {
        let mut count = 0;
        inspect(source, &mut count, 0)?;
        copy(
            source,
            target,
            flag(plan, 'r') || flag(plan, 'R'),
            flag(plan, 'n'),
            flag(plan, 'p'),
            &mut count,
            0,
        )
    }
}

fn inspect(source: &mut dyn Entry, count: &mut usize, depth: usize) -> io::Result<()> {
    bounded(count, depth)?;
    let kind = source.entry_type()?;
    if kind == "DIRECTORY" {
        for name in source.names()? {
            let mut child = source.child(&name)?;
            inspect(child.as_mut(), count, depth + 1)?;
        }
    } else if kind != "FILE" {
        return Err(code("LINK_OR_SPECIAL_FILE"));
    }
    Ok(())
}

fn copy(
    source: &mut dyn Entry,
    target: &mut dyn Entry,
    recursive: bool,
    no_clobber: bool,
    preserve: bool,
    count: &mut usize,
    depth: usize,
) -> io::Result<()> {
    bounded(count, depth)?;
    let kind = source.entry_type()?;
    if kind == "DIRECTORY" {
        if !recursive {
            return Err(code("RECURSIVE_COPY_REQUIRED"));
        }
        if target.entry_type()? == "MISSING" {
            target.make_directory()?;
        }
        if target.entry_type()? != "DIRECTORY" {
            return Err(code("DESTINATION_DIRECTORY_REQUIRED"));
        }
        for name in source.names()? {
            let mut from = source.child(&name)?;
            let mut to = target.child(&name)?;
            copy(from.as_mut(), to.as_mut(), true, no_clobber, preserve, count, depth + 1)?;
        }
        if preserve {
            source.metadata_to(target)?;
        }
        return Ok(());
    }
    if kind != "FILE" {
        return Err(code("LINK_OR_SPECIAL_FILE"));
    }
    if no_clobber && target.entry_type()? != "MISSING" {
        return Ok(());
    }
    {
        let mut input = source.read()?;
        let mut output = target.write()?;
        let mut buffer = [0u8; 32768];
        loop {
            let size = input.read(&mut buffer)?;
            cancelled()?;
            if size == 0 {
                break;
            }
            output.write_all(&buffer[..size])?;
        }
        cancelled()?;
    }
    if preserve {
        source.metadata_to(target)?;
    }
    Ok(())
}

fn remove(
    entry: &mut dyn Entry,
    recursive: bool,
    force: bool,
    count: &mut usize,
    depth: usize,
) -> io::Result<()> {
    bounded(count, depth)?;
    let kind = entry.entry_type()?;
    if kind == "MISSING" {
        if force {
            return Ok(());
        }
        return Err(code("FILE_MISSING"));
    }
    if kind == "DIRECTORY" {
        if !recursive {
            return Err(code("RECURSIVE_DELETE_REQUIRED"));
        }
        for name in entry.names()? {
            let mut child = entry.child(&name)?;
            remove(child.as_mut(), true, force, count, depth + 1)?;
        }
    } else if kind != "FILE" {
        return Err(code("LINK_OR_SPECIAL_FILE"));
    }
    cancelled()?;
    entry.delete()
}

fn bounded(count: &mut usize, depth: usize) -> io::Result<()> {
    cancelled()?;
    *count += 1;
    if *count > 20000 || depth > 128 {
        return Err(code("FILE_OPERATION_LIMIT"));
    }
    Ok(())
}

/// 计划标志（`-x`/`-abc`/`--` 终止；原版 `flag()`）。
pub fn flag(plan: &FilePlan, flag: char) -> bool {
    for value in plan.argv.iter().skip(1) {
        if value == "--" {
            break;
        }
        if value.starts_with('-') && value[1..].contains(flag) {
            return true;
        }
    }
    false
}

/// 只规范化系统共享存储根；从此根以下的每一级都必须 NOFOLLOW。
pub fn write_root(
    policy: &dyn DevicePolicy,
    value: &str,
) -> io::Result<String> {
    let path = policy.normalize(value)?;
    if !policy.write_allowed(&path) {
        return Err(code("PROTECTED_WRITE_PATH"));
    }
    if path.starts_with("/data/local/tmp/") {
        return Ok("/data/local/tmp".to_string());
    }
    let parts: Vec<&str> = path[1..].split('/').collect();
    Ok(if parts[1] == "emulated" {
        format!("/storage/emulated/{}", parts[2])
    } else {
        format!("/storage/{}", parts[1])
    })
}

fn code(text: &str) -> io::Error {
    io::Error::other(text.to_string())
}

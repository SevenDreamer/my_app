// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.GuestScriptBudget —— 现代化重构，行为契约不变。
//! 查询与短意图命令共用排队、准备和执行的协作总期限；不把安装预算套到列表。
//! 错误契约：`SCRIPT_BUDGET` / `SCRIPT_QUEUE_CANCELLED` / `<phase>_CANCELLED` / `<phase>_TIMEOUT`。

use std::cell::RefCell;
use std::io::{self, Read};
use std::rc::Rc;
use std::time::{Duration, Instant};

/// 查询总期限（30 秒）。
pub const QUERY_TIMEOUT_MS: u64 = 30_000;

struct Budget {
    deadline: Instant,
    cancelled: Box<dyn Fn() -> bool>,
    phase: String,
    parent: Option<Rc<Budget>>,
}

thread_local! {
    static CURRENT: RefCell<Option<Rc<Budget>>> = const { RefCell::new(None) };
}

/// 协作期限句柄（原版 ThreadLocal 链 → 线程局部 + Rc 链）。
pub struct GuestScriptBudget {
    inner: Rc<Budget>,
}

impl GuestScriptBudget {
    /// `millis` < 1 = `SCRIPT_BUDGET`。
    pub fn new(millis: u64, cancelled: Box<dyn Fn() -> bool>, phase: &str) -> Self {
        assert!(millis >= 1, "SCRIPT_BUDGET");
        let parent = CURRENT.with(|c| c.borrow().clone());
        GuestScriptBudget {
            inner: Rc::new(Budget {
                deadline: Instant::now() + Duration::from_millis(millis),
                cancelled,
                phase: phase.to_string(),
                parent,
            }),
        }
    }

    /// 剩余毫秒（与父链取最小）；`SCRIPT_QUEUE_CANCELLED` / `<phase>_CANCELLED` / `<phase>_TIMEOUT`。
    pub fn remaining_ms(&self) -> io::Result<u64> {
        let inner = &self.inner;
        if (inner.cancelled)() {
            return Err(io::Error::other(format!("{}_CANCELLED", inner.phase)));
        }
        let left = inner.deadline.saturating_duration_since(Instant::now());
        if left.is_zero() {
            return Err(io::Error::other(format!("{}_TIMEOUT", inner.phase)));
        }
        let remaining = left.as_millis().max(1) as u64;
        Ok(match &inner.parent {
            Some(parent) => {
                let outer = GuestScriptBudget { inner: parent.clone() };
                remaining.min(outer.remaining_ms()?)
            }
            None => remaining,
        })
    }

    /// 保留原调用任务的所有权：后续 guest 准备和执行继承提交时已开始的期限。
    pub fn enter(&self) -> Scope {
        let previous = CURRENT.with(|c| c.borrow_mut().replace(self.inner.clone()));
        Scope { previous }
    }
}

/// 退出作用域恢复前一期限。
pub struct Scope {
    previous: Option<Rc<Budget>>,
}

impl Drop for Scope {
    fn drop(&mut self) {
        let previous = self.previous.take();
        CURRENT.with(|c| *c.borrow_mut() = previous);
    }
}

/// 仅本线程已有查询期限时检查；不会中断正在提交的文件发布或更改其它调用。
pub fn checkpoint() -> io::Result<()> {
    let active = CURRENT.with(|c| c.borrow().clone());
    if let Some(inner) = active {
        let budget = GuestScriptBudget { inner };
        budget.remaining_ms()?;
    }
    Ok(())
}

/// 在实际读块前后协作截止；单次内核读取本身仍须等待其返回。
pub fn guard(source: &mut dyn Read) -> GuardedRead<'_> {
    GuardedRead { source }
}

pub struct GuardedRead<'a> {
    source: &'a mut dyn Read,
}

impl Read for GuardedRead<'_> {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        checkpoint()?;
        let count = self.source.read(buf)?;
        checkpoint()?;
        Ok(count)
    }
}

// 版权来源：DSHA（MIT）com.deepseekharness.app.backup.BackupControl —— 现代化重构，行为契约不变。
//! 核心不持有界面；取消只在可安全中止的流式阶段响应，事务提交自行收敛。
//! 错误契约：取消 = `io::ErrorKind::Interrupted` + 文案 `CANCELLED`。

use std::io;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

/// 进度回调（阶段名，条目数，字节数）。
pub type ProgressFn = Arc<dyn Fn(&str, i64, i64) + Send + Sync>;

/// 取消门（共享句柄；进度回调按需附加）。
#[derive(Clone, Default)]
pub struct BackupControl {
    cancelled: Arc<AtomicBool>,
    progress: Option<ProgressFn>,
}

impl BackupControl {
    pub fn new() -> Self {
        Self::default()
    }

    /// 附带进度回调（原版 `BackupControl(Progress)`）。
    pub fn with_progress(progress: ProgressFn) -> Self {
        BackupControl { cancelled: Arc::new(AtomicBool::new(false)), progress: Some(progress) }
    }

    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::SeqCst)
    }

    /// 请求取消（幂等）。
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
    }

    /// 可安全中止点；已取消则中断（`CANCELLED`）。
    pub fn check(&self) -> io::Result<()> {
        if self.is_cancelled() {
            return Err(io::Error::new(io::ErrorKind::Interrupted, "CANCELLED"));
        }
        Ok(())
    }

    /// 进度回报（原版 `report`）：先过取消门，再回调。
    pub fn report(
        &self,
        phase: &str,
        entries: i64,
        bytes: i64,
    ) -> io::Result<()> {
        self.check()?;
        if let Some(progress) = &self.progress {
            progress(phase, entries, bytes);
        }
        Ok(())
    }
}

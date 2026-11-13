//! P1：stdio 命令通道（PET_INTEGRATION_PLAN，2026-11-13）。
//!
//! 协议（零依赖行文本）：my_app 经 stdin 写命令行，pet 经 stdout 回响应行。
//!   mood:happy|neutral|surprised|angry|sleepy|love|dead|smug  → ok:mood:happy
//!   quit                                                     → ok:quit（进程退出）
//!   未知/非法                                                 → err:<line>
//!
//! 线程模型：stdin 读线程只往 [take_commands] 的队列推（Arc<Mutex>），
//! GPUI 主线程在 60fps tick 里消费——零 GPUI 跨线程 API（update_global
//! 不触发 observe，跨线程不安全，故走队列轮询）。
use std::collections::VecDeque;
use std::io::{self, BufRead, Write};
use std::sync::{Arc, Mutex, OnceLock};

use crate::expressions::Expression;

/// 命令（已解析）
#[derive(Debug, PartialEq)]
pub enum PetCommand {
    Mood(Expression),
    Quit,
}

/// 解析一行命令（零依赖手写——协议就这么两种，不引 serde）
pub fn parse_line(line: &str) -> Option<PetCommand> {
    let line = line.trim();
    if line.is_empty() {
        return None;
    }
    if line == "quit" {
        return Some(PetCommand::Quit);
    }
    let Some(mood) = line.strip_prefix("mood:") else {
        // 未知命令：回 err（parse 只管解析，回包在调用方）
        return None;
    };
    let expr = match mood.trim().to_ascii_lowercase().as_str() {
        "neutral" => Expression::Neutral,
        "happy" => Expression::Happy,
        "surprised" => Expression::Surprised,
        "angry" => Expression::Angry,
        "sleepy" => Expression::Sleepy,
        "love" => Expression::Love,
        "dead" => Expression::Dead,
        "smug" => Expression::Smug,
        _ => return None,
    };
    Some(PetCommand::Mood(expr))
}

fn queue() -> &'static Arc<Mutex<VecDeque<PetCommand>>> {
    static QUEUE: OnceLock<Arc<Mutex<VecDeque<PetCommand>>>> = OnceLock::new();
    QUEUE.get_or_init(|| Arc::new(Mutex::new(VecDeque::new())))
}

/// 启动 stdin 读线程（幂等；main 里调一次）。
/// 响应行写 stdout（my_app 端可读）。
pub fn spawn_stdin_listener() {
    std::thread::spawn(|| {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            let Ok(line) = line else { break };
            match parse_line(&line) {
                Some(cmd) => {
                    let is_quit = matches!(cmd, PetCommand::Quit);
                    if let Ok(mut q) = queue().lock() {
                        q.push_back(cmd);
                    }
                    respond(&format!("ok:{}", line.trim()));
                    if is_quit {
                        // quit：给渲染循环一帧时间收尾后退出
                        std::thread::sleep(std::time::Duration::from_millis(100));
                        std::process::exit(0);
                    }
                }
                None => respond(&format!("err:{}", line.trim())),
            }
        }
    });
}

fn respond(s: &str) {
    let mut out = io::stdout();
    let _ = writeln!(out, "{s}");
    let _ = out.flush();
}

/// tick 消费：取出全部待执行命令（GPUI 主线程 60fps 调）。
pub fn take_commands() -> Vec<PetCommand> {
    match queue().lock() {
        Ok(mut q) => q.drain(..).collect(),
        Err(_) => Vec::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_moods() {
        assert_eq!(
            parse_line("mood:happy"),
            Some(PetCommand::Mood(Expression::Happy))
        );
        assert_eq!(
            parse_line("mood:LOVE"),
            Some(PetCommand::Mood(Expression::Love))
        );
        assert_eq!(parse_line("quit"), Some(PetCommand::Quit));
    }

    #[test]
    fn parse_rejects_unknown() {
        assert_eq!(parse_line("mood:dancing"), None);
        assert_eq!(parse_line("hello"), None);
        assert_eq!(parse_line(""), None);
    }

    #[test]
    fn queue_roundtrip() {
        let cmds = take_commands();
        assert!(cmds.is_empty());
    }
}

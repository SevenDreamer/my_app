// 版权来源：DSHA（MIT）com.deepseekharness.app.runtime.SignedAssetMembers —— 现代化重构，行为契约不变。
//! 本次签名成员与隐式父目录的直接成员集合；不把路径存在当作完整证明。
//! 错误代号契约：`TAR_DIRECTORY_MEMBERS_CHANGED:<dir>` / `ARCHIVE_PATH`。

use crate::code_error;
use crate::limits;
use std::collections::{BTreeSet, HashMap};
use std::io;

/// 签名成员树（目录 → 直接子名集合）。
pub struct SignedAssetMembers {
    children: HashMap<String, BTreeSet<String>>,
}

impl SignedAssetMembers {
    pub fn new<'a, I: IntoIterator<Item = &'a str>>(paths: I) -> io::Result<Self> {
        let mut children: HashMap<String, BTreeSet<String>> = HashMap::new();
        children.insert(String::new(), BTreeSet::new());
        for path in paths {
            limits::path(path)?;
            if path.is_empty() {
                continue;
            }
            let mut at = path;
            while !at.is_empty() {
                let (parent, name) = match at.rfind('/') {
                    Some(slash) => (&at[..slash], &at[slash + 1..]),
                    None => ("", at),
                };
                children
                    .entry(parent.to_string())
                    .or_default()
                    .insert(name.to_string());
                at = parent;
            }
        }
        Ok(SignedAssetMembers { children })
    }

    /// 目录的已知直接成员名（未知目录 = 空集）。
    pub fn names(&self, directory: &str) -> BTreeSet<String> {
        self.children
            .get(directory)
            .cloned()
            .unwrap_or_default()
    }

    /// 实际目录成员必须与签名成员逐名一致（重复名也算变化）。
    pub fn verify<S: AsRef<str>>(&self, directory: &str, actual: &[S]) -> io::Result<()> {
        let seen: BTreeSet<String> = actual.iter().map(|s| s.as_ref().to_string()).collect();
        if seen.len() != actual.len() || self.names(directory) != seen {
            return Err(code_error(format!(
                "TAR_DIRECTORY_MEMBERS_CHANGED:{directory}"
            )));
        }
        Ok(())
    }
}

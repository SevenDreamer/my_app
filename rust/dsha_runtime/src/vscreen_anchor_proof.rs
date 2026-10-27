// 版权来源：DSHA（MIT）com.deepseekharness.app.vscreen.VirtualScreenAnchorProof —— 现代化重构，行为契约不变。
//! 私有完整语义证明：节点树 → 规范化字节流 → SHA-256 摘要 + 锚点候选。
//! 「字符串与节点句柄都不是诊断输出」（原版类注释）。
//!
//! Android 摘取面（AccessibilityService 窗口清单、`context.validateRoot`、
//! `SystemClock.elapsedRealtime`、节点 recycle）留在接线缝，经 [AnchorNode]/
//! [WindowSource]/[Clock] 供给；**摘要序列化、预算、截止期、候选/几何判定**全部
//! 在此实现——错误代号契约（逐字）：
//! `ANCHOR_TREE_BUDGET`/`ANCHOR_WINDOW_BUDGET`/`ANCHOR_WINDOW_AMBIGUOUS`/
//! `ANCHOR_WINDOW_GEOMETRY_UNAVAILABLE`/`ANCHOR_WINDOW_INCOMPLETE`/
//! `ANCHOR_PROOF_DEADLINE`/`ANCHOR_TREE_INCOMPLETE`/`ANCHOR_CANDIDATE_BUDGET`/
//! `ANCHOR_SEMANTIC_EXTRAS_UNSUPPORTED`/`INVALID_COORDINATE`/`ANCHOR_AMBIGUOUS`/
//! `ANCHOR_GEOMETRY_UNAVAILABLE`/`ANCHOR_NODE_UNAVAILABLE`/`ANCHOR_OCCLUDED`。
//! （`ANCHOR_ACCESSIBILITY_UNAVAILABLE`/`ANCHOR_WINDOW_INVENTORY_UNAVAILABLE`/
//! `ANCHOR_TREE_UNAVAILABLE` 为摘取缝代号，缝侧抛出。）
//! 常量契约：NODE_LIMIT=4096、DEPTH_LIMIT=64、CANDIDATE_LIMIT=128、METADATA_LIMIT=1MiB、
//! 截止期 = 构造后 1000ms、几何余量 ±8、窗口子级上限 64、动作上限 64、extras 上限 64。

use sha2::{Digest, Sha256};
use std::io;

pub const NODE_LIMIT: u32 = 4096;
pub const DEPTH_LIMIT: i32 = 64;
pub const CANDIDATE_LIMIT: usize = 128;
pub const METADATA_LIMIT: u64 = 1024 * 1024;
const PROOF_DEADLINE_MS: u64 = 1000;
const WINDOW_CHILD_LIMIT: i32 = 64;
const ACTION_LIMIT: usize = 64;
const EXTRAS_LIMIT: usize = 64;
const EXTRA_INT_ARRAY_LIMIT: usize = 4096;
const EXTRA_STRING_ARRAY_LIMIT: usize = 128;
const GEOMETRY_MARGIN: i32 = 8;
/// 契约常量（Android `AccessibilityNodeInfo.ACTION_CLICK`）。
pub const ACTION_CLICK: i32 = 1;

fn unavailable(code: &str) -> io::Error {
    io::Error::other(code.to_string())
}

/// 单调时钟（原版 `android.os.SystemClock.elapsedRealtime`）。
pub trait Clock {
    fn millis(&self) -> u64;
}

/// 屏幕矩形（原版 `android.graphics.Rect` 判定语义）。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

impl Rect {
    pub fn is_empty(&self) -> bool {
        self.left >= self.right || self.top >= self.bottom
    }

    /// Java `Rect.contains(x, y)`：left ≤ x < right 且 top ≤ y < bottom。
    pub fn contains(&self, x: i32, y: i32) -> bool {
        x >= self.left && x < self.right && y >= self.top && y < self.bottom
    }

    /// Java `Rect.intersects`（严格不等）。
    pub fn intersects(&self, other: &Rect) -> bool {
        self.left < other.right
            && other.left < self.right
            && self.top < other.bottom
            && other.top < self.bottom
    }

    /// 余量 ±8 并夹到视口（原版 `region`）。
    pub fn region(&self, width: i32, height: i32) -> Rect {
        Rect {
            left: (self.left - GEOMETRY_MARGIN).max(0),
            top: (self.top - GEOMETRY_MARGIN).max(0),
            right: (self.right + GEOMETRY_MARGIN).min(width),
            bottom: (self.bottom + GEOMETRY_MARGIN).min(height),
        }
    }
}

/// extras 值形态（原版 `Bundle` 基元分支；未知形态显式拒）。
#[derive(Clone, Debug)]
pub enum ExtraValue {
    Null,
    Text(String),
    /// Number/Boolean：类名（`getClass().getName()`）+ `toString()`，两者都进摘要。
    Primitive(String, String),
    IntArray(Vec<i32>),
    StringArray(Vec<String>),
}

/// 节点视图（接线缝：Android `AccessibilityNodeInfo` 逐字段供给）。
pub trait AnchorNode {
    type Node: AnchorNode<Handle = Self::Handle>;
    type Handle: Clone + PartialEq;

    fn handle(&self) -> Self::Handle;
    fn window_id(&self) -> i32;
    fn hash_code(&self) -> i32;
    fn class_name(&self) -> Option<&str>;
    fn package_name(&self) -> Option<&str>;
    fn view_id_resource_name(&self) -> Option<&str>;
    fn unique_id(&self) -> Option<&str>;
    fn bounds(&self) -> Rect;
    /// 22 个标志位，顺序即摘要顺序：
    /// visible/enabled/clickable/longClickable/editable/scrollable/checkable/checked/
    /// selected/focusable/focused/accessibilityFocused/password/contentInvalid/
    /// dismissable/multiLine/contextClickable/heading/showingHintText/
    /// screenReaderFocusable/importantForAccessibility/textEntryKey。
    fn flags(&self) -> [bool; 22];
    /// 7 段文本，顺序：text/contentDescription/stateDescription/hintText/error/
    /// tooltipText/paneTitle。
    fn texts(&self) -> [Option<String>; 7];
    fn text_selection(&self) -> (i32, i32);
    fn input_type(&self) -> i32;
    fn live_region(&self) -> i32;
    fn drawing_order(&self) -> i32;
    fn max_text_length(&self) -> i32;
    fn movement_granularities(&self) -> i32;
    /// (type, min, max, current)——浮点按 `f32::to_bits` 进摘要。
    fn range_info(&self) -> Option<(i32, f32, f32, f32)>;
    /// (rowCount, columnCount, hierarchical, selectionMode)。
    fn collection_info(&self) -> Option<(i32, i32, bool, i32)>;
    /// (rowIndex, rowSpan, columnIndex, columnSpan, heading, selected)。
    fn collection_item(&self) -> Option<(i32, i32, i32, i32, bool, bool)>;
    fn extras(&self) -> Vec<(String, ExtraValue)>;
    /// (actionId, label) 原始序；摘要前按 id 稳定排序。
    fn actions(&self) -> Vec<(i32, Option<String>)>;
    fn child_count(&self) -> i32;
    fn child(&self, index: i32) -> Option<Self::Node>;
}

/// 窗口视图（接线缝：Android `AccessibilityWindowInfo`）。
pub trait WindowSource {
    fn display_id(&self) -> i32;
    fn id(&self) -> i32;
    fn window_type(&self) -> i32;
    fn layer(&self) -> i32;
    fn bounds(&self) -> Rect;
    fn is_focused(&self) -> bool;
    fn is_active(&self) -> bool;
    fn is_accessibility_focused(&self) -> bool;
    fn title(&self) -> Option<&str>;
    fn parent_id(&self) -> Option<i32>;
    fn child_count(&self) -> i32;
    fn child_id(&self, index: i32) -> Option<i32>;
}

/// 锚点候选（原版 `Candidate`；句柄由缝侧持有-obtain 语义）。
#[derive(Clone, Debug)]
pub struct Candidate<H> {
    pub handle: H,
    pub bounds: Rect,
    pub path: String,
}

/// 语义树证明（原版 `VirtualScreenAnchorProof` 摘要/候选主体）。
pub struct AnchorProof<H: Clone + PartialEq> {
    hash: Sha256,
    pub candidates: Vec<Candidate<H>>,
    windows: Vec<(i32, Rect)>,
    bytes: u64,
    nodes: u32,
    display: i32,
    window: i32,
    connection_epoch: i64,
    include_unique_id: bool,
    deadline_ms: u64,
    clock: Box<dyn Clock>,
    digest: Option<Vec<u8>>,
    closed: bool,
}

impl<H: Clone + PartialEq> AnchorProof<H> {
    /// 构造即写入证明头：number(display)、number(window)、text(packageName)。
    pub fn new(
        display: i32,
        window: i32,
        package_name: &str,
        connection_epoch: i64,
        include_unique_id: bool,
        clock: Box<dyn Clock>,
    ) -> io::Result<Self> {
        let deadline_ms = clock.millis() + PROOF_DEADLINE_MS;
        let mut proof = AnchorProof {
            hash: Sha256::new(),
            candidates: Vec::new(),
            windows: Vec::new(),
            bytes: 0,
            nodes: 0,
            display,
            window,
            connection_epoch,
            include_unique_id,
            deadline_ms,
            clock,
            digest: None,
            closed: false,
        };
        proof.number(display);
        proof.number(window);
        proof.text(Some(package_name))?;
        Ok(proof)
    }

    /// 窗口清单摄取（调用前按窗口 id 排序；每窗口一次）。
    pub fn ingest_window<W: WindowSource>(&mut self, w: &W) -> io::Result<()> {
        if self.closed {
            return Err(unavailable("ANCHOR_TREE_UNAVAILABLE"));
        }
        let last = self.windows.last().map(|(id, _)| *id).unwrap_or(-1);
        if w.display_id() != self.display || w.id() == last {
            return Err(unavailable("ANCHOR_WINDOW_AMBIGUOUS"));
        }
        let bounds = w.bounds();
        if bounds.is_empty() {
            return Err(unavailable("ANCHOR_WINDOW_GEOMETRY_UNAVAILABLE"));
        }
        self.bytes += 512 + 4 * w.child_count() as u64;
        if self.bytes > METADATA_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        self.windows.push((w.id(), bounds));
        self.number(w.id());
        self.number(w.window_type());
        self.number(w.layer());
        self.rect(bounds);
        self.flag(w.is_focused());
        self.flag(w.is_active());
        self.flag(w.is_accessibility_focused());
        self.text(w.title())?;
        self.number(w.parent_id().unwrap_or(-1));
        if w.child_count() > WINDOW_CHILD_LIMIT {
            return Err(unavailable("ANCHOR_WINDOW_BUDGET"));
        }
        self.number(w.child_count());
        for i in 0..w.child_count() {
            match w.child_id(i) {
                Some(id) => self.number(id),
                None => return Err(unavailable("ANCHOR_WINDOW_INCOMPLETE")),
            }
        }
        Ok(())
    }

    /// 树走查（原版 `walk`，pre-order；path 根 "0"，子级 `父/i`）。
    pub fn walk<N>(&mut self, node: &N, path: &str, depth: i32) -> io::Result<()>
    where
        N: AnchorNode<Handle = H>,
    {
        if self.clock.millis() > self.deadline_ms {
            return Err(unavailable("ANCHOR_PROOF_DEADLINE"));
        }
        if depth > DEPTH_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        self.nodes += 1;
        if self.nodes > NODE_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        self.bytes += 512;
        if self.bytes > METADATA_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        if node.window_id() != self.window {
            return Err(unavailable("ANCHOR_TREE_INCOMPLETE"));
        }
        self.text(Some(path))?;
        self.number(node.hash_code());
        self.text(node.class_name())?;
        self.text(node.package_name())?;
        self.text(node.view_id_resource_name())?;
        if self.include_unique_id {
            self.text(node.unique_id())?;
        }
        let bounds = node.bounds();
        self.rect(bounds);
        for flag in node.flags() {
            self.flag(flag);
        }
        for text in node.texts() {
            self.text(text.as_deref())?;
        }
        let (start, end) = node.text_selection();
        self.number(start);
        self.number(end);
        self.number(node.input_type());
        self.number(node.live_region());
        self.number(node.drawing_order());
        self.number(node.max_text_length());
        self.number(node.movement_granularities());
        match node.range_info() {
            None => self.flag(false),
            Some((kind, min, max, current)) => {
                self.flag(true);
                self.number(kind);
                self.number(min.to_bits() as i32);
                self.number(max.to_bits() as i32);
                self.number(current.to_bits() as i32);
            }
        }
        match node.collection_info() {
            None => self.flag(false),
            Some((rows, columns, hierarchical, selection_mode)) => {
                self.flag(true);
                self.number(rows);
                self.number(columns);
                self.flag(hierarchical);
                self.number(selection_mode);
            }
        }
        match node.collection_item() {
            None => self.flag(false),
            Some((row, row_span, column, column_span, heading, selected)) => {
                self.flag(true);
                self.number(row);
                self.number(row_span);
                self.number(column);
                self.number(column_span);
                self.flag(heading);
                self.flag(selected);
            }
        }
        // 基元 extras 全量比较；未知 parcelable 不得静默忽略。
        self.extras(node.extras())?;
        let mut actions = node.actions();
        if actions.len() > ACTION_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        // Java List.sort 稳定排序（id 相同保持原始序）。
        actions.sort_by_key(|(id, _)| *id);
        self.number(actions.len() as i32);
        let mut click = false;
        for (id, label) in &actions {
            self.number(*id);
            self.text(label.as_deref())?;
            click |= *id == ACTION_CLICK;
        }
        if click && node.flags()[2] && node.flags()[1] && node.flags()[0] && !bounds.is_empty() {
            if self.candidates.len() >= CANDIDATE_LIMIT {
                return Err(unavailable("ANCHOR_CANDIDATE_BUDGET"));
            }
            self.bytes += 512;
            if self.bytes > METADATA_LIMIT {
                return Err(unavailable("ANCHOR_TREE_BUDGET"));
            }
            self.candidates.push(Candidate {
                handle: node.handle(),
                bounds,
                path: path.to_string(),
            });
        }
        let children = node.child_count();
        if children < 0 || children as u32 > NODE_LIMIT - self.nodes {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        self.number(children);
        for i in 0..children {
            let child = node.child(i).ok_or_else(|| unavailable("ANCHOR_TREE_INCOMPLETE"))?;
            self.walk(&child, &format!("{path}/{i}"), depth + 1)?;
        }
        Ok(())
    }

    /// 收口（原版 capture 尾部 `proof.hash.digest()`）。
    pub fn finish(&mut self) -> io::Result<Vec<u8>> {
        if self.closed {
            return Err(unavailable("ANCHOR_TREE_UNAVAILABLE"));
        }
        if self.digest.is_none() {
            self.digest = Some(self.hash.clone().finalize().to_vec());
        }
        Ok(self.digest.clone().expect("just computed"))
    }

    /// 坐标选锚（原版 `select`）。
    pub fn select(&self, x: i32, y: i32, width: i32, height: i32) -> io::Result<&Candidate<H>> {
        if x < 0 || y < 0 || x >= width || y >= height {
            return Err(unavailable("INVALID_COORDINATE"));
        }
        let mut result: Option<&Candidate<H>> = None;
        for candidate in &self.candidates {
            if !candidate.bounds.contains(x, y) {
                continue;
            }
            if result.is_some() {
                return Err(unavailable("ANCHOR_AMBIGUOUS"));
            }
            let r = candidate.bounds;
            if r.left < 0 || r.top < 0 || r.right > width || r.bottom > height {
                return Err(unavailable("ANCHOR_GEOMETRY_UNAVAILABLE"));
            }
            result = Some(candidate);
        }
        let result = result.ok_or_else(|| unavailable("ANCHOR_NODE_UNAVAILABLE"))?;
        let region = result.bounds.region(width, height);
        if !self.unobscured(region) {
            return Err(unavailable("ANCHOR_OCCLUDED"));
        }
        Ok(result)
    }

    /// 同路径/句柄/几何再认（原版 `same`）。
    pub fn same(&self, handle: &H, bounds: Rect, path: &str) -> Option<&Candidate<H>> {
        self.candidates.iter().find(|c| {
            c.path == path && c.handle == *handle && c.bounds == bounds
        })
    }

    /// 无他窗遮挡（原版 `unobscured`）。
    pub fn unobscured(&self, region: Rect) -> bool {
        self.windows
            .iter()
            .all(|(id, bounds)| *id == self.window || !bounds.intersects(&region))
    }

    /// 同证明比对：连接纪元 + 常时摘要比较（原版 `MessageDigest.isEqual`）。
    pub fn same_as(&self, other: &AnchorProof<H>) -> bool {
        match (&self.digest, &other.digest) {
            (Some(a), Some(b)) => {
                self.connection_epoch == other.connection_epoch && constant_time_eq(a, b)
            }
            _ => false,
        }
    }

    /// 幂等收尾（句柄回收由缝侧 Drop 负责）。
    pub fn close(&mut self) {
        if self.closed {
            return;
        }
        self.closed = true;
        self.candidates.clear();
        self.windows.clear();
    }

    fn rect(&mut self, rect: Rect) {
        self.number(rect.left);
        self.number(rect.top);
        self.number(rect.right);
        self.number(rect.bottom);
    }

    fn flag(&mut self, value: bool) {
        self.hash.update([value as u8]);
    }

    fn number(&mut self, value: i32) {
        self.hash.update(value.to_be_bytes());
    }

    fn text(&mut self, value: Option<&str>) -> io::Result<()> {
        let Some(value) = value else {
            self.number(-1);
            return Ok(());
        };
        let utf16_len = value.encode_utf16().count();
        if utf16_len as u64 > METADATA_LIMIT / 2 {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        let encoded = value.as_bytes();
        // Java `2L * value.length()`：length = UTF-16 码元数。
        self.bytes += (encoded.len() as u64).max(2 * utf16_len as u64);
        if self.bytes > METADATA_LIMIT {
            return Err(unavailable("ANCHOR_TREE_BUDGET"));
        }
        self.number(encoded.len() as i32);
        self.hash.update(encoded);
        Ok(())
    }

    fn extras(&mut self, values: Vec<(String, ExtraValue)>) -> io::Result<()> {
        if values.len() > EXTRAS_LIMIT {
            return Err(unavailable("ANCHOR_SEMANTIC_EXTRAS_UNSUPPORTED"));
        }
        let mut values = values;
        // Java Collections.sort(String) = UTF-16 码元序（增补平面字符亦然）。
        values.sort_by_key(|(key, _)| key.encode_utf16().collect::<Vec<u16>>());
        self.number(values.len() as i32);
        for (key, value) in values {
            self.text(Some(&key))?;
            match value {
                ExtraValue::Null => self.text(Some("null"))?,
                ExtraValue::Text(sequence) => {
                    self.text(Some("text"))?;
                    self.text(Some(&sequence))?;
                }
                ExtraValue::Primitive(class_name, value) => {
                    self.text(Some(&class_name))?;
                    self.text(Some(&value))?;
                }
                ExtraValue::IntArray(items) => {
                    if items.len() > EXTRA_INT_ARRAY_LIMIT {
                        return Err(unavailable("ANCHOR_SEMANTIC_EXTRAS_UNSUPPORTED"));
                    }
                    self.bytes += 4 * items.len() as u64;
                    if self.bytes > METADATA_LIMIT {
                        return Err(unavailable("ANCHOR_TREE_BUDGET"));
                    }
                    self.text(Some("int[]"))?;
                    self.number(items.len() as i32);
                    for item in items {
                        self.number(item);
                    }
                }
                ExtraValue::StringArray(items) => {
                    if items.len() > EXTRA_STRING_ARRAY_LIMIT {
                        return Err(unavailable("ANCHOR_SEMANTIC_EXTRAS_UNSUPPORTED"));
                    }
                    self.text(Some("String[]"))?;
                    self.number(items.len() as i32);
                    for item in items {
                        self.text(Some(&item))?;
                    }
                }
            }
        }
        Ok(())
    }
}

/// 常时比较（原版 `MessageDigest.isEqual`）。
pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (x, y) in a.iter().zip(b) {
        diff |= x ^ y;
    }
    diff == 0
}

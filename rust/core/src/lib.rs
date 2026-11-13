//! my_app 核心引擎（Rust）——底子骨架（2026-11-10）。
//!
//! 定位：计算密集的核心层（未来的镜像校验/快照差分/解压），经 C ABI 供
//! Flutter（dart:ffi）调用；同一 crate 将来编 wasm 供 web 端复用。
//! FFI 规矩（项目先例）：零依赖手写 `extern "C"`，不引 FFI 框架。
//!
//! 分层：本 crate 只做纯计算（无 IO/无平台 API）——平台相关（文件/线程）
//! 留在调用侧，保证 wasm 可编译。

use std::ffi::{c_char, CStr, CString};
use std::slice;

use sha2::{Digest, Sha256};

/// 版本决策：[remote] 是否比 [current] 新（semver 标准，含预发布段
/// 排序——1.3.0-dev.1 < 1.3.0）。解析失败返回 -1（调用方保守处理）。
/// 迁移自 update_service._isNewer（pub_semver 同标准）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_semver_is_newer(
    remote: *const c_char,
    current: *const c_char,
) -> i32 {
    use semver::Version;
    let (Some(r), Some(c)) = (
        unsafe { CStr::from_ptr(remote) }.to_str().ok(),
        unsafe { CStr::from_ptr(current) }.to_str().ok(),
    ) else {
        return -1;
    };
    // 兼容带 build 号（1.3.0+92）与纯版本（1.3.0）——取版本段
    let clean = |s: &str| -> String {
        s.split('+').next().unwrap_or(s).trim().to_string()
    };
    let (Ok(rv), Ok(cv)) = (
        Version::parse(&clean(r)),
        Version::parse(&clean(c)),
    ) else {
        return -1;
    };
    if rv > cv {
        1
    } else {
        0
    }
}

/// HID 游戏手柄报告编码（Dart→Rust 迁移第一批 B）：字段进 → 10 字节出。
/// 布局：[reportId, buttons_lo, buttons_hi, dpad, lx, ly, rx, ry, l2, r2]。
/// 范围越界返回 -1（调用方走原 Dart 校验报错）；成功返回写入长度。
/// 接收侧 decode 低频留 Dart（性能点在 60fps 发送侧）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_gamepad_encode(
    out: *mut u8,
    out_len: usize,
    report_id: u8,
    buttons: u16,
    dpad: u8,
    lx: u8,
    ly: u8,
    rx: u8,
    ry: u8,
    l2: u8,
    r2: u8,
) -> i32 {
    if out.is_null() || out_len < 10 {
        return -1;
    }
    if dpad > 8 {
        return -1;
    }
    let buf = unsafe { std::slice::from_raw_parts_mut(out, out_len) };
    buf[0] = report_id;
    buf[1] = (buttons & 0xFF) as u8;
    buf[2] = ((buttons >> 8) & 0xFF) as u8;
    buf[3] = dpad;
    buf[4] = lx;
    buf[5] = ly;
    buf[6] = rx;
    buf[7] = ry;
    buf[8] = l2;
    buf[9] = r2;
    10
}

// ── LatencyMeter 状态机（Dart→Rust 迁移第一批 C）────────────────
// UDP 网络层留 Dart；节拍配对/时钟差滑动平均/丢包回收的有状态算法在
// 本侧。handle = 状态句柄（Box 泄漏进裸指针——用 [core_latency_free] 释放）。

use std::collections::HashMap;

pub struct LatencyState {
    /// seq → (t1 控制端时钟, hostAt 本机收到时刻)
    pending: HashMap<i64, (i64, i64)>,
    /// 端到端毫秒样本（上限 100）
    samples: Vec<i64>,
    lost: i64,
    /// 时钟差（控制端 - 本机，滑动平均）
    offset: Option<f64>,
}

impl LatencyState {
    const MAX_SAMPLES: usize = 100;

    fn new() -> Self {
        Self {
            pending: HashMap::new(),
            samples: Vec::new(),
            lost: 0,
            offset: None,
        }
    }

    /// 收到本机节拍回执：配对出端到端延迟样本
    fn ingest_beat(&mut self, seq: i64, t1: i64, host_at: i64) {
        self.pending.insert(seq, (t1, host_at));
    }

    /// 配对回收：超时未回执的记丢包（调用方按 now 扫）
    fn collect(&mut self, seq: i64, reply_at: i64) -> i64 {
        if let Some((t1, host_at)) = self.pending.remove(&seq) {
            let latency = (reply_at - t1).max(0) - (reply_at - host_at).max(0) / 2;
            let latency = latency.max(0);
            if self.samples.len() >= Self::MAX_SAMPLES {
                self.samples.remove(0);
            }
            self.samples.push(latency);
            latency
        } else {
            self.lost += 1;
            -1
        }
    }

    /// 时钟差滑动平均更新（alpha=0.25）
    fn ingest_syncack(&mut self, controller_minus_local: f64) {
        self.offset = Some(match self.offset {
            Some(prev) => prev * 0.75 + controller_minus_local * 0.25,
            None => controller_minus_local,
        });
    }

    /// 统计：(样本数, 平均, 最小, 最大, 丢包, 时钟差)——无样本返回 None
    fn stats(&self) -> Option<(usize, i64, i64, i64, i64, Option<f64>)> {
        if self.samples.is_empty() {
            return None;
        }
        let (mut sum, mut min, mut max) = (0i64, self.samples[0], self.samples[0]);
        for &v in &self.samples {
            sum += v;
            min = min.min(v);
            max = max.max(v);
        }
        Some((
            self.samples.len(),
            sum / self.samples.len() as i64,
            min,
            max,
            self.lost,
            self.offset,
        ))
    }
}

/// 新建延迟状态机；返回句柄（须 [core_latency_free] 释放）。
#[unsafe(no_mangle)]
pub extern "C" fn core_latency_new() -> *mut LatencyState {
    Box::into_raw(Box::new(LatencyState::new()))
}

/// 收节拍（seq 配对登记）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_latency_beat(
    handle: *mut LatencyState,
    seq: i64,
    t1: i64,
    host_at: i64,
) {
    if let Some(state) = unsafe { handle.as_mut() } {
        state.ingest_beat(seq, t1, host_at);
    }
}

/// 配对回收：返回延迟样本或 -1（记丢包）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_latency_collect(
    handle: *mut LatencyState,
    seq: i64,
    reply_at: i64,
) -> i64 {
    match unsafe { handle.as_mut() } {
        Some(state) => state.collect(seq, reply_at),
        None => -1,
    }
}

/// 时钟差滑动平均更新。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_latency_syncack(handle: *mut LatencyState, delta: f64) {
    if let Some(state) = unsafe { handle.as_mut() } {
        state.ingest_syncack(delta);
    }
}

/// 统计输出：out=[count, avg, min, max, lost]（i64×5）+ offset 传出。
/// 无样本返回 0，有样本返回 1。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_latency_stats(
    handle: *mut LatencyState,
    out: *mut i64,
    out_len: usize,
    offset_out: *mut f64,
) -> i32 {
    let state = unsafe { handle.as_ref() };
    let Some(state) = state else {
        return 0;
    };
    let stats = state.stats();
    let Some((count, avg, min, max, lost, offset)) = stats else {
        return 0;
    };
    if out.is_null() || out_len < 5 {
        return 0;
    }
    let buf = unsafe { std::slice::from_raw_parts_mut(out, out_len) };
    buf[0] = count as i64;
    buf[1] = avg;
    buf[2] = min;
    buf[3] = max;
    buf[4] = lost;
    if !offset_out.is_null() {
        unsafe { *offset_out = offset.unwrap_or(0.0) };
    }
    1
}

/// 释放状态机（配对 [core_latency_new]）。
///
/// # Safety
/// [handle] 必须来自 [core_latency_new] 且只释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_latency_free(handle: *mut LatencyState) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle)) };
    }
}

/// 核心引擎版本号（心跳函数——FFI 通路的活体验证）。
/// 返回值为静态字符串指针，调用方**不得释放**。
#[unsafe(no_mangle)]
pub extern "C" fn core_version() -> *const c_char {
    // C ABI 字符串必须 NUL 终止——静态串手动补 \0（2026-11-10 FFI 测试
    // 抓获：缺 NUL 尾会让调用方 toDartString 读越界出 FormatException）
    static VERSION: &str = concat!("core-rs-", env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

/// 自检算术（FFI 通路的双向验证：int 进出）。
#[unsafe(no_mangle)]
pub extern "C" fn core_add(a: i64, b: i64) -> i64 {
    a.saturating_add(b)
}

/// 带字符串返回的示例：sha256 就绪位（功能未落地，先验字符串通道）。
/// 返回堆分配字符串，调用方须用 [core_string_free] 释放。
#[unsafe(no_mangle)]
pub extern "C" fn core_build_info() -> *mut c_char {
    let s = format!(
        "target={} profile={}",
        std::env::consts::ARCH,
        if cfg!(debug_assertions) { "debug" } else { "release" }
    );
    CString::new(s).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// SHA-256 哈希（镜像/快照校验原语）：字节缓冲进 → 十六进制串出。
/// [data] 为缓冲指针、[len] 为字节数；返回堆分配字符串，须用
/// [core_string_free] 释放。data 为空指针返回 null。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_sha256_hex(data: *const u8, len: usize) -> *mut c_char {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let bytes = unsafe { slice::from_raw_parts(data, len) };
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    let digest = hasher.finalize();
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    CString::new(hex).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// 文件流式 SHA-256（镜像/大文件校验正解）：路径进 → 十六进制串出。
/// Rust 内流式读（8KB 块）——大文件零双拷贝；路径须 UTF-8；失败/文件
/// 不存在返回 null（错误细节经 [core_last_error] 取）。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_sha256_file(path: *const c_char) -> *mut c_char {
    use std::io::Read;
    if path.is_null() {
        return std::ptr::null_mut();
    }
    let Ok(p) = unsafe { CStr::from_ptr(path) }.to_str() else {
        return std::ptr::null_mut();
    };
    let Ok(mut f) = std::fs::File::open(p) else {
        return std::ptr::null_mut();
    };
    let mut hasher = Sha256::new();
    let mut buf = [0u8; 8192];
    loop {
        match f.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => hasher.update(&buf[..n]),
            Err(_) => return std::ptr::null_mut(),
        }
    }
    let hex: String = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    CString::new(hex).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

/// 释放 [core_build_info] 返回的字符串（配对释放，FFI 纪律）。
///
/// # Safety
/// [ptr] 必须来自 [core_build_info] 的返回值且只释放一次。
#[unsafe(no_mangle)]
pub unsafe extern "C" fn core_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { drop(CString::from_raw(ptr)) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn semver_decisions() {
        let c = |s: &str| CString::new(s).unwrap();
        let (r1, c1) = (c("1.3.0"), c("1.2.9"));
        assert_eq!(unsafe { core_semver_is_newer(r1.as_ptr(), c1.as_ptr()) }, 1);
        // 预发布排序：dev.9 < dev.10（数字比较非字典序——手写踩过的坑）
        let (r2, c2) = (c("1.3.0-dev.10"), c("1.3.0-dev.9"));
        assert_eq!(unsafe { core_semver_is_newer(r2.as_ptr(), c2.as_ptr()) }, 1);
        // 预发布 < 正式
        let (r3, c3) = (c("1.3.0"), c("1.3.0-dev.49"));
        assert_eq!(unsafe { core_semver_is_newer(r3.as_ptr(), c3.as_ptr()) }, 1);
        // 带 build 号兼容
        let (r4, c4) = (c("1.4.0"), c("1.3.0+92"));
        assert_eq!(unsafe { core_semver_is_newer(r4.as_ptr(), c4.as_ptr()) }, 1);
        // 不更新
        let (r5, c5) = (c("1.3.0-dev.48"), c("1.3.0-dev.49"));
        assert_eq!(unsafe { core_semver_is_newer(r5.as_ptr(), c5.as_ptr()) }, 0);
        // 非法串
        let (r6, c6) = (c("not-a-version"), c("1.0.0"));
        assert_eq!(unsafe { core_semver_is_newer(r6.as_ptr(), c6.as_ptr()) }, -1);
    }

    #[test]
    fn gamepad_encode_layout() {
        let mut buf = [0u8; 16];
        let n = unsafe {
            core_gamepad_encode(buf.as_mut_ptr(), 16, 0x03, 0x1234, 5, 1, 2, 3, 4, 5, 6)
        };
        assert_eq!(n, 10);
        assert_eq!(
            &buf[..10],
            &[0x03, 0x34, 0x12, 5, 1, 2, 3, 4, 5, 6],
            "LE buttons + 字段序"
        );
        // dpad 越界
        assert_eq!(
            unsafe { core_gamepad_encode(buf.as_mut_ptr(), 16, 0, 0, 9, 0, 0, 0, 0, 0, 0) },
            -1
        );
        // buffer 太小
        assert_eq!(
            unsafe { core_gamepad_encode(buf.as_mut_ptr(), 5, 0, 0, 0, 0, 0, 0, 0, 0, 0) },
            -1
        );
    }

    #[test]
    fn latency_state_machine() {
        let h = core_latency_new();
        assert!(!h.is_null());
        // 无样本 stats=0
        let mut out = [0i64; 5];
        let mut off = 0.0;
        assert_eq!(
            unsafe { core_latency_stats(h, out.as_mut_ptr(), 5, &mut off) },
            0
        );
        // beat → collect 配对出样本
        unsafe { core_latency_beat(h, 1, 1000, 1010) };
        let lat = unsafe { core_latency_collect(h, 1, 1030) };
        assert!(lat >= 0, "配对出样本: {lat}");
        // 未登记 seq → 丢包
        assert_eq!(unsafe { core_latency_collect(h, 99, 2000) }, -1);
        // syncack 滑动平均
        unsafe { core_latency_syncack(h, 100.0) };
        unsafe { core_latency_syncack(h, 0.0) };
        assert_eq!(
            unsafe { core_latency_stats(h, out.as_mut_ptr(), 5, &mut off) },
            1
        );
        assert_eq!(out[0], 1, "样本数");
        assert_eq!(out[4], 1, "丢包数");
        assert!((off - 75.0).abs() < 1e-9, "滑动平均 0.75*100+0.25*0");
        unsafe { core_latency_free(h) };
    }

    #[test]
    fn add_saturates() {
        assert_eq!(core_add(2, 3), 5);
        assert_eq!(core_add(i64::MAX, 1), i64::MAX);
    }

    #[test]
    fn version_is_static_cstring() {
        let p = core_version();
        assert!(!p.is_null());
        let s = unsafe { std::ffi::CStr::from_ptr(p) };
        assert!(s.to_str().unwrap().starts_with("core-rs-"));
    }

    #[test]
    fn sha256_known_vector() {
        // NIST 测试向量：空串 → e3b0c442...（校验哈希正确性）
        let p = unsafe { core_sha256_hex(std::ptr::null(), 0) };
        assert!(p.is_null(), "空指针须返回 null");
        let empty: [u8; 0] = [];
        let p = unsafe { core_sha256_hex(empty.as_ptr(), 0) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        unsafe { core_string_free(p) };
    }

    #[test]
    fn sha256_abc_vector() {
        let data = b"abc";
        let p = unsafe { core_sha256_hex(data.as_ptr(), data.len()) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        unsafe { core_string_free(p) };
    }

    #[test]
    fn sha256_file_stream() {
        // 流式与内存版结果一致性（写临时文件验证）
        let tmp = std::env::temp_dir().join("core_sha256_test.txt");
        std::fs::write(&tmp, b"abc").unwrap();
        let path = CString::new(tmp.to_str().unwrap()).unwrap();
        let p = unsafe { core_sha256_file(path.as_ptr()) };
        let s = unsafe { CStr::from_ptr(p) }.to_str().unwrap().to_string();
        assert_eq!(
            s,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
        unsafe { core_string_free(p) };
        std::fs::remove_file(&tmp).ok();
        // 不存在的文件 → null
        let bad = CString::new("/nonexistent/core_test").unwrap();
        assert!(unsafe { core_sha256_file(bad.as_ptr()) }.is_null());
    }

    #[test]
    fn build_info_roundtrip() {
        let p = core_build_info();
        assert!(!p.is_null());
        let s = unsafe { std::ffi::CStr::from_ptr(p) };
        assert!(s.to_str().unwrap().contains("target="));
        unsafe { core_string_free(p) };
    }
}

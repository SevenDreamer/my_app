//! 零依赖 Win32 FFI：光标屏幕位置 + 系统 DPI（菜单定位 / 视线跟随用）
//!
//! AGENTS 规则：FFI 一律手写 extern "system" 声明，不引 windows-sys。

#[repr(C)]
#[derive(Clone, Copy, Default)]
struct WinPoint {
    x: i32,
    y: i32,
}

#[link(name = "user32")]
unsafe extern "system" {
    /// 光标位置（物理像素，虚拟屏坐标）
    fn GetCursorPos(lp_point: *mut WinPoint) -> i32;
    /// 主屏 DPI（96 = 100% 缩放；Win10 1703+）
    fn GetDpiForSystem() -> u32;
}

/// 当前光标位置（物理像素）
pub fn cursor_physical() -> (f32, f32) {
    let mut p = WinPoint::default();
    // SAFETY: 结构体布局与 Win32 POINT 一致，函数总是写入合法指针
    unsafe {
        GetCursorPos(&mut p);
    }
    (p.x as f32, p.y as f32)
}

/// 系统缩放比（100% → 1.0；150% → 1.5）
pub fn scale() -> f32 {
    // SAFETY: 无参数要求，返回 DPI 值
    let dpi = unsafe { GetDpiForSystem() };
    if dpi == 0 {
        1.0
    } else {
        dpi as f32 / 96.0
    }
}

/// 当前光标位置（逻辑像素——物理 / 系统缩放，与 GPUI 窗口坐标对齐）
pub fn cursor_logical() -> (f32, f32) {
    let (x, y) = cursor_physical();
    let s = scale();
    (x / s, y / s)
}

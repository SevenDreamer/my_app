//! my_app 桌宠（pet）：独立 Rust/GPUI 小窗，浮在桌面上的机器人眼睛
//!
//! P0 骨架：黑底矩形小窗（无原生标题栏、PopUp 置顶、整窗可拖动）。
//! 技术栈与 Y 项目同源（gpui rev b1a7ef0）；移植路线见 docs/RUST_PET.md。
use gpui::prelude::*;
use gpui::{
    div, Bounds, MouseButton, TitlebarOptions, Window, WindowBounds, WindowKind,
    WindowOptions, WindowControlArea, px, size,
};
use gpui_platform::application;

fn main() {
    // gpui_platform::application：平台初始化入口（与 Y 项目一致）
    application().run(|cx: &mut gpui::App| {
        // 眼睛窗尺寸：按 15:11 点阵放大后的比例（440×180，后续按渲染微调）
        let bounds = Bounds::centered(None, size(px(440.0), px(180.0)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                // PopUp = 官方语义「出现在所有窗口之上」（置顶）
                kind: WindowKind::PopUp,
                // 隐藏原生标题栏（黑底窗自绘）
                titlebar: Some(TitlebarOptions {
                    appears_transparent: true,
                    ..Default::default()
                }),
                is_movable: true,
                is_resizable: false,
                is_minimizable: false,
                ..Default::default()
            },
            |_, cx| cx.new(|_| PetWindow::new()),
        )
        .unwrap();
        cx.activate(true);
    });
}

/// 桌宠根视图：整窗黑底 + 拖动；P0 阶段先放占位内容
struct PetWindow;

impl PetWindow {
    fn new() -> Self {
        Self
    }
}

impl Render for PetWindow {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div()
            // 交互标识：GPUI 按 id 追踪 hover/hitbox（gpui-desktop-app skill 规则）
            .id("pet-root")
            .w_full()
            .h_full()
            .flex()
            .items_center()
            .justify_center()
            // 桌宠黑底（与 Flutter 眼睛页同款 #000000）
            .bg(gpui::rgb(0x000000))
            // 整窗拖动：WindowControlArea::Drag（Windows=HTCAPTION）+
            // on_mouse_down 手动 start_window_move（skill 规则：双保险缺一不可）
            .window_control_area(WindowControlArea::Drag)
            .on_mouse_down(MouseButton::Left, |_, window, _| {
                window.start_window_move();
            })
            .child(div().text_color(gpui::rgb(0x333333)).child("pet · P0"))
    }
}

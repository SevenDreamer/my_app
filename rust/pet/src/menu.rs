//! 右键菜单窗：表情列表 + 退出（独立 PopUp 小窗，携带主窗弱引用）
//!
//! 点表情 → 通过 WeakEntity 更新 PetWindow 的表情并关本窗；
//! 点退出 → 进程级退出（桌宠 v1 的关闭途径）。
use gpui::prelude::*;
use gpui::{
    Bounds, Context, Entity, MouseButton, TitlebarOptions, Window,
    WindowBounds, WindowControlArea, WindowKind, WindowOptions, div, point, px,
    rgb, size,
};

use crate::PetWindow;
use crate::expressions::Expression;

/// 菜单行高 / 窗口宽（逻辑像素）
const ROW_H: f32 = 34.0;
const MENU_W: f32 = 168.0;

/// 菜单窗总高：8 表情 + 分隔区 + 退出 + 上下内边距
pub fn menu_height() -> f32 {
    ROW_H * 9.0 + 16.0
}

/// 在光标处打开菜单窗（由主窗右键触发）
pub fn open(cx: &mut gpui::App, pet: Entity<PetWindow>) {
    let (x, y) = crate::win::cursor_logical();
    let bounds = Bounds::new(point(px(x), px(y)), size(px(MENU_W), px(menu_height())));
    let options = WindowOptions {
        window_bounds: Some(WindowBounds::Windowed(bounds)),
        // PopUp：置顶 + 不进任务栏 + 无标题栏（同主窗结论）
        kind: WindowKind::PopUp,
        titlebar: Some(TitlebarOptions {
            appears_transparent: true,
            ..Default::default()
        }),
        focus: true,
        is_movable: false,
        is_resizable: false,
        is_minimizable: false,
        ..Default::default()
    };
    let _ = cx.open_window(options, |_, cx| cx.new(|_| PetMenu::new(pet)));
}

/// 菜单视图：黑卡片 + 表情列表 + 退出
struct PetMenu {
    pet: Entity<PetWindow>,
}

impl PetMenu {
    fn new(pet: Entity<PetWindow>) -> Self {
        Self { pet }
    }

    /// 一行菜单项：文字 + hover 高亮 + 点击回调
    fn menu_row(
        id: &'static str,
        label: &'static str,
        active: bool,
        on_click: impl Fn(&mut Window, &mut gpui::App) + 'static,
    ) -> impl IntoElement {
        let on_click = std::rc::Rc::new(on_click);
        div()
            .id(id)
            .flex()
            .items_center()
            .h(px(ROW_H - 2.0))
            .mx(px(6.0))
            .px(px(10.0))
            .rounded(px(6.0))
            // 当前表情高亮（zinc-800 蓝调提示改用 primary 淡底：10% 白）
            .when(active, |el| el.bg(rgb(0x262626)))
            .hover(|el| el.bg(rgb(0x2f2f2f)))
            .cursor_pointer()
            .on_mouse_down(MouseButton::Left, move |_, window, cx| {
                on_click(window, cx);
            })
            .child(
                div()
                    .w_full()
                    .text_color(rgb(0xfafafa))
                    .child(label),
            )
    }
}

impl Render for PetMenu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let current = self.pet.read(cx).eye.to;

        // 表情行：点击选中（外层先克隆——闭包不可 move self 字段）
        let pet_base = self.pet.clone();
        let rows = Expression::ALL.into_iter().map(|e| {
            let pet = pet_base.clone();
            let label: &'static str = e.label();
            Self::menu_row(
                // ElementId 要求稳定字符串：用表达式名（静态）
                match e {
                    Expression::Neutral => "expr-neutral",
                    Expression::Happy => "expr-happy",
                    Expression::Surprised => "expr-surprised",
                    Expression::Angry => "expr-angry",
                    Expression::Sleepy => "expr-sleepy",
                    Expression::Love => "expr-love",
                    Expression::Dead => "expr-dead",
                    Expression::Smug => "expr-smug",
                },
                label,
                e == current,
                move |window, cx| {
                    let _ = pet.update(cx, |pet, cx| {
                        pet.set_expression(e);
                        cx.notify();
                    });
                    // 事件派发中不能直接关窗（skill 规则：必须 defer）
                    window.defer(cx, |window, _| {
                        window.remove_window();
                    });
                },
            )
        });

        div()
            .id("pet-menu")
            .flex()
            .flex_col()
            .w(px(MENU_W))
            .bg(rgb(0x18181b)) // zinc-900 卡片
            .border_1()
            .border_color(rgb(0x333333))
            .rounded(px(8.0))
            .py(px(6.0))
            .overflow_hidden()
            .children(rows)
            // 分隔线
            .child(
                div()
                    .h(px(1.0))
                    .mx(px(10.0))
                    .my(px(5.0))
                    .bg(rgb(0x333333)),
            )
            // 退出行
            .child(Self::menu_row(
                "menu-quit",
                "退出",
                false,
                |window, cx| {
                    // 桌宠无主窗生命周期管理：直接进程退出
                    window.defer(cx, |_, _| {
                        std::process::exit(0);
                    });
                },
            ))
            // 整窗拖动不可用（菜单只响应点击）
            .window_control_area(WindowControlArea::Drag)
    }
}

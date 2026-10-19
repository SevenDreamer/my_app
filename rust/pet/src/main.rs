//! my_app 桌宠（pet）：独立 Rust/GPUI 小窗，浮在桌面上的机器人眼睛
//!
//! P1：LED 点阵眼睛（表情/眨眼/闪变过渡）+ 整窗拖动 + 右键循环表情。
//! 表情语义与点阵移植自 Flutter 侧 robot_eyes 功能。
mod expressions;
mod eyes;
mod render;

use std::time::Duration;

use gpui::prelude::*;
use gpui::{
    Bounds, MouseButton, TitlebarOptions, Window, WindowBounds, WindowControlArea,
    WindowKind, WindowOptions, canvas, div, px, size,
};
use gpui_platform::application;

use crate::eyes::EyeState;

fn main() {
    // gpui_platform::application：平台初始化入口（与 Y 项目一致）
    application().run(|cx: &mut gpui::App| {
        // 眼睛窗尺寸：15:11x2+间隙 的点阵放大（460x180）
        let bounds = Bounds::centered(None, size(px(460.0), px(180.0)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                // PopUp = 官方语义「出现在所有窗口之上」（置顶；实测不进任务栏）
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
            |window, cx| cx.new(|cx| PetWindow::new(window, cx)),
        )
        .unwrap();
        cx.activate(true);
    });
}

/// 桌宠根视图：黑底 + canvas 眼睛 + 60fps 状态推进
struct PetWindow {
    eye: EyeState,
}

impl PetWindow {
    fn new(_window: &mut Window, cx: &mut Context<Self>) -> Self {
        // 60fps 心跳：推进状态机并请求重渲染（等价游戏循环）
        cx.spawn(async move |this, cx| {
            loop {
                cx.background_executor()
                    .timer(Duration::from_millis(16))
                    .await;
                // 实体已销毁则退出循环
                let alive = this
                    .update(cx, |this, cx| {
                        this.eye.tick(1.0 / 60.0);
                        cx.notify(); // 每帧重渲染
                        true
                    })
                    .unwrap_or(false);
                if !alive {
                    break;
                }
            }
        })
        .detach();

        Self {
            eye: EyeState::new(),
        }
    }
}

impl Render for PetWindow {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        // canvas 闭包要求 'static：每帧克隆一份状态快照进闭包
        let state = self.eye.clone();

        // 右键循环下一个表情（gpui 规则：闭包回调用 entity.update 模式）
        let entity = cx.entity();
        let on_right_click = move |_: &gpui::MouseDownEvent, _window: &mut gpui::Window, cx: &mut gpui::App| {
            let _ = entity.update(cx, |this, cx| {
                let next = this.eye.to.next();
                this.eye.set_expression(next);
                cx.notify();
            });
        };

        div()
            // 交互标识：GPUI 按 id 追踪 hover/hitbox
            .id("pet-root")
            .w_full()
            .h_full()
            .bg(gpui::rgb(0x000000))
            // 整窗拖动：WindowControlArea::Drag（HTCAPTION）+ 手动 move 双保险
            .window_control_area(WindowControlArea::Drag)
            .on_mouse_down(MouseButton::Left, |_, window, _| {
                window.start_window_move();
            })
            // 右键：切换表情（带 ~200ms 过渡 + LED 闪变）
            .on_mouse_down(MouseButton::Right, on_right_click)
            // 眼睛画布：paint 回调里走点阵渲染
            .child(canvas(
                |_, _, _| {},
                move |bounds, _, window, _| {
                    render::render_eyes(window, bounds, &state);
                },
            ))
    }
}

//! my_app 桌宠（pet）：独立 Rust/GPUI 小窗，浮在桌面上的机器人眼睛
//!
//! P2：LED 点阵眼睛 + 整窗拖动 + 右键菜单（表情/退出）+ 全局鼠标视线跟随。
//! 表情语义与点阵移植自 Flutter 侧 robot_eyes 功能。
mod command;
mod expressions;
mod eyes;
mod menu;
mod render;
mod win;

use std::time::Duration;

use gpui::prelude::*;
use gpui::{
    Bounds, MouseButton, TitlebarOptions, Window, WindowBounds, WindowControlArea,
    WindowKind, WindowOptions, canvas, div, px, size,
};
use gpui_platform::application;

use crate::expressions::Expression;
use crate::eyes::EyeState;

fn main() {
    // P1：stdio 命令通道（my_app 经 stdin 控制情绪/退出）
    command::spawn_stdin_listener();
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
                        // P1：消费 stdin 命令队列（零 GPUI 跨线程——tick 轮询）
                        for cmd in command::take_commands() {
                            if let command::PetCommand::Mood(expr) = cmd {
                                this.eye.set_expression(expr);
                            }
                        }
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

    /// 供菜单窗调用：切换表情
    pub fn set_expression(&mut self, next: Expression) {
        self.eye.set_expression(next);
    }
}

impl Render for PetWindow {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        // ── 视线跟随（全局光标）：光标在屏幕任何位置都盯着看 ──
        let (cur_x, cur_y) = win::cursor_logical();
        let bounds = _window.bounds();
        let center = bounds.center();
        let half_w = bounds.size.width.as_f32() / 2.0;
        let half_h = bounds.size.height.as_f32() / 2.0;
        if half_w > 0.0 && half_h > 0.0 {
            self.eye.look = (
                ((cur_x - center.x.as_f32()) / half_w).clamp(-1.0, 1.0),
                ((cur_y - center.y.as_f32()) / half_h).clamp(-1.0, 1.0),
            );
        }

        // canvas 闭包要求 'static：每帧克隆一份状态快照进闭包
        let state = self.eye.clone();

        // 右键：打开菜单窗（表情列表 + 退出），携带主窗实体引用
        let pet = cx.entity();
        let on_right_click = move |_: &gpui::MouseDownEvent, _window: &mut gpui::Window, cx: &mut gpui::App| {
            menu::open(cx, pet.clone()); // 闭包须 Fn：每次调用克隆传入
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
            // 右键：菜单（v1 无关闭途径的补全——含「退出」）
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

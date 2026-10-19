//! canvas 绘制：LED 点阵（方形灯珠，三级亮度）
//!
//! 算法移植自 Flutter `led_dot_renderer.dart` 的 paint()：
//! 眨眼裁剪 / 右眼镜像采样 / hash 闪变过渡 / 瞳孔叠加（屏幕坐标不镜像、
//! 表情固有偏置左右对称）。光晕层暂未移植（P1 先保方块观感）。
use gpui::{Bounds, Hsla, Pixels, Window, fill, point, size};

use crate::expressions::{COLS, OUTLINES, PUPILS, ROWS};
use crate::eyes::EyeState;

/// 两眼之间空出的灯珠列数
const GAP_COLS: usize = 5;

/// LED 青色主色 #00E5FF（≈ hsl(187, 100%, 46%)）
fn led_color(alpha: f32) -> Hsla {
    Hsla {
        h: 0.519,
        s: 1.0,
        l: 0.46,
        a: alpha,
    }
}

/// 在给定画布区域内绘制一双眼睛（bounds = canvas 元素布局出的矩形）
pub fn render_eyes(window: &mut Window, bounds: Bounds<Pixels>, state: &EyeState) {
    let width = bounds.size.width;
    let height = bounds.size.height;

    // 几何布局（与 Flutter 侧一致）：gap=灯珠间距，radius=灯珠半宽
    let gap = width / (COLS * 2 + GAP_COLS) as f32;
    let radius = gap * 0.34;
    let grid_h = ROWS as f32 * gap;
    let top = (height - grid_h) / 2.0;

    // 单眼几何中心（小数坐标，瞳孔平滑移动用）
    let cx0 = (COLS - 1) as f32 / 2.0;
    let cy0 = (ROWS - 1) as f32 / 2.0;

    // 瞳孔参数随过渡插值
    let t = state.transition;
    let (r_from, bx_from, by_from) = PUPILS[state.from.index()];
    let (r_to, bx_to, by_to) = PUPILS[state.to.index()];
    let pupil_r = r_from + (r_to - r_from) * t;
    let bias_x = bx_from + (bx_to - bx_from) * t;
    let bias_y = by_from + (by_to - by_from) * t;

    for eye in 0..2 {
        let mirror = eye == 1; // 右眼模板水平镜像
        let origin_x = (eye * (COLS + GAP_COLS)) as f32 * gap;
        let from_map = OUTLINES[state.from.index()];
        let to_map = OUTLINES[state.to.index()];

        for r in 0..ROWS {
            for c in 0..COLS {
                let x = bounds.origin.x + origin_x + (c as f32 + 0.5) * gap;
                let y = bounds.origin.y + top + (r as f32 + 0.5) * gap;

                // ── 眨眼裁剪：亮区向中线收缩 ──
                let half = (ROWS as f32 / 2.0) * (1.0 - state.blink);
                let blink_off = (r as f32 - cy0).abs() > half + 0.5;

                // ── 模板采样：右眼用镜像列号 ──
                let sc = if mirror { COLS - 1 - c } else { c };
                let on_from = from_map[r].as_bytes()[sc] == b'#';
                let on_to = to_map[r].as_bytes()[sc] == b'#';
                // 随机灯珠翻转过渡：固定 hash 决定每格何时翻（LED 颗粒闪变质感）
                let hash = ((sc * 31 + r * 17) % 97) as f32 / 97.0;
                let on = if hash < t { on_to } else { on_from };

                // ── 瞳孔叠加：屏幕坐标不镜像（视线同向），偏置左右对称 ──
                let px_ = cx0
                    + state.look.0 * COLS as f32 * 0.30
                    + if mirror { -bias_x } else { bias_x };
                let py_ = cy0 + state.look.1 * ROWS as f32 * 0.30 + bias_y;
                let pdx = c as f32 - px_;
                let pdy = r as f32 - py_;
                let in_pupil = pupil_r > 0.0
                    && !blink_off
                    && pdx * pdx + pdy * pdy <= pupil_r * pupil_r;

                // ── 三级亮度：瞳孔内亮珠 / 眼眶中亮 / 熄灭底座 ──
                let alpha = if on && !blink_off && in_pupil {
                    1.0
                } else if on && !blink_off {
                    0.41 // ≈ Flutter 的 105/255
                } else {
                    0.055 // ≈ 14/255 底座
                };

                // 方形灯珠：边长 2.05*radius（与 Flutter 的 _drawSquare 一致）
                let side = radius * 2.05;
                let quad = Bounds::new(
                    point(x - side / 2.0, y - side / 2.0),
                    size(side, side),
                );
                window.paint_quad(fill(quad, led_color(alpha)));
            }
        }
    }
}

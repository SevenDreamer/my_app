//! 眼睛状态机：表情过渡 + 眨眼调度
//!
//! 语义移植自 Flutter 侧 `led_eyes.dart` 的 EyeVisualState 驱动逻辑：
//! 表情切换做 ~200ms 过渡、眨眼随机间隔 2~6s、闭合/张开约 70/90ms。
use rand::Rng;

use crate::expressions::Expression;

/// 眼睛可视状态（渲染层只读这五个公开字段，与 Flutter 的 EyeVisualState 对齐）
#[derive(Clone)]
pub struct EyeState {
    /// 过渡起点表情 / 终点表情（渲染层做逐格闪变混合）
    pub from: Expression,
    pub to: Expression,
    /// 表情过渡进度 0..1
    pub transition: f32,
    /// 眨眼进度 0..1（0=睁开，1=全闭）
    pub blink: f32,
    /// 视线偏移 -1..1（P2 接鼠标跟随，当前恒居中）
    pub look: (f32, f32),

    // ── 内部驱动 ──
    /// 距下次眨眼的剩余秒数
    blink_wait: f32,
    /// true=正在闭合；false 且 blink>0 =正在张开
    blinking_out: bool,
}

impl EyeState {
    pub fn new() -> Self {
        Self {
            from: Expression::Neutral,
            to: Expression::Neutral,
            transition: 1.0,
            blink: 0.0,
            look: (0.0, 0.0),
            blink_wait: Self::random_blink_delay(),
            blinking_out: false,
        }
    }

    /// 随机眨眼间隔（2~6 秒，与 Flutter 侧手感一致）
    fn random_blink_delay() -> f32 {
        rand::rng().random_range(2.0..6.0)
    }

    /// 切换表情：从"当前目标"起做过渡（连点会从中间状态接续）
    pub fn set_expression(&mut self, next: Expression) {
        if next == self.to {
            return;
        }
        self.from = self.to;
        self.to = next;
        self.transition = 0.0;
    }

    /// 推进一帧：dt 单位秒（约 60fps 调一次）
    pub fn tick(&mut self, dt: f32) {
        // 表情过渡 ~200ms
        if self.transition < 1.0 {
            self.transition = (self.transition + dt * 5.0).min(1.0);
        }

        // 眨眼三态：等待 → 闭合(70ms) → 张开(90ms) → 新等待
        if self.blinking_out {
            self.blink += dt / 0.07;
            if self.blink >= 1.0 {
                self.blink = 1.0;
                self.blinking_out = false; // 到全闭，转入张开
            }
        } else if self.blink > 0.0 {
            self.blink -= dt / 0.09;
            if self.blink <= 0.0 {
                self.blink = 0.0;
                self.blink_wait = Self::random_blink_delay();
            }
        } else {
            self.blink_wait -= dt;
            if self.blink_wait <= 0.0 {
                self.blinking_out = true;
            }
        }
    }
}

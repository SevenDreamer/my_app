# Rust 桌宠（pet）· 架构与路线

> `rust/` 是 my_app 的 Rust 侧（Cargo workspace）；`pet` 是第一位成员——
> 浮在桌面上的机器人眼睛（参考 BongoCat 的定位）。
> 技术栈：GPUI（zed `b1a7ef0` / gpui 0.2.2，与 Y 项目同 rev 同缓存）。

## 构建与运行

```bash
cd rust
cargo +nightly build          # 必须 nightly（stable 编不了 gpui，见 PITFALLS #11）
cargo +nightly run -p pet     # 运行桌宠
```

产物：`rust/target/debug/pet.exe`（release 后续随 Flutter 打包进 Release zip）。

## 模块结构

```
rust/pet/src/
├── main.rs         窗口（PopUp 置顶/无边框/不进任务栏）+ 60fps 心跳 + 交互接线
├── expressions.rs  表情语义（8 种）+ LED 点阵模板 + 瞳孔参数（移植自 Flutter）
├── eyes.rs         眼睛状态机：表情过渡(~200ms) + 眨眼三态(2~6s 随机)
└── render.rs       canvas 三级亮度方块点阵（算法 1:1 移植自 led_dot_renderer.dart）
```

## Dart → Rust 移植对照

| Flutter（robot_eyes/） | Rust（pet/src/） | 说明 |
|---|---|---|
| expressions.dart（语义枚举） | expressions.rs | 8 表情一一对应 |
| eyes/led_dot_renderer.dart | expressions.rs + render.rs | 点阵/瞳孔/绘制算法 |
| widgets/led_eyes.dart（状态机） | eyes.rs | blink/过渡/look 语义对齐 |
| inputs/pointer_look_source.dart | main.rs（cursor FFI） | 视线跟随（P2） |

## 窗口形态结论（实测）

`WindowKind::PopUp` + `appears_transparent`：**置顶 ✓ / 不进任务栏 ✓ /
无原生标题栏 ✓**——全部 GPUI 原生达成，零 Win32 样式 FFI。
拖动 = `WindowControlArea::Drag` + `start_window_move` 双保险（skill 规则）。

## 路线

- [x] P0 骨架：窗口形态四要素（截图验收 4/4）
- [x] P1 眼睛：LED 点阵渲染 + 表情/眨眼/闪变过渡 + 右键循环表情
- [ ] P2 交互：全局鼠标视线跟随（GetCursorPos FFI）+ 右键菜单（表情列表/退出）
- [ ] P3 集成：Flutter「我」页启动入口 + Release 打包附 pet.exe
- [ ] P4+：光晕层、全局键鼠联动（BongoCat 式）、透明异形窗

## 交互约定（v1）

- 左键拖动移动窗口
- 右键循环 8 个表情（带闪变过渡）——P2 升级为菜单
- 关闭：进程级（P2 起提供菜单「退出」）

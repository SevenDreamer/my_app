---
version: alpha
name: my_app
description: 简洁现代的个人工具箱。shadcn zinc 近单色（黑白灰）基调、无彩色强调、统一的圆角与间距——工具感优先，装饰最少化。
colors:
  primary: "#18181B"
  secondary: "#71717A"
  neutral: "#FFFFFF"
  surface: "#FFFFFF"
  on-surface: "#09090B"
  error: "#DC2626"
  border: "#E4E4E7"
typography:
  h1:
    fontFamily: system-ui
    fontSize: 1.75rem
    fontWeight: 700
    lineHeight: 1.25
  display:
    fontFamily: system-ui
    fontSize: 2.25rem
    fontWeight: 600
    lineHeight: 1.15
  body-md:
    fontFamily: system-ui
    fontSize: 1rem
    fontWeight: 400
    lineHeight: 1.5
  label-sm:
    fontFamily: system-ui
    fontSize: 0.8125rem
    fontWeight: 500
    lineHeight: 1.4
rounded:
  sm: 6px
  md: 10px
  lg: 16px
spacing:
  sm: 8px
  md: 16px
  lg: 24px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FAFAFA"
    rounded: "{rounded.md}"
    padding: 12px
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.lg}"
    padding: 16px
  list-tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-md}"
    padding: "12px 16px"
  icon-block:
    backgroundColor: "#E8E8E8"
    textColor: "{colors.primary}"
    rounded: 8px
    size: 40px
  input-field:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: 12px
  text-caption:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    typography: "{typography.label-sm}"
  status-error:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.error}"
    typography: "{typography.label-sm}"
    padding: 8px
  stat-block:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.display}"
    rounded: "{rounded.lg}"
    padding: 16px
  status-badge:
    backgroundColor: "primary-10pct"
    textColor: "{colors.primary}"
    typography: "{typography.label-sm}"
    rounded: 9999px
    padding: "4px 8px"
  progress-bar:
    backgroundColor: "{colors.border}"
    textColor: "{colors.primary}"
    rounded: 9999px
    size: 4px
  action-row:
    padding: 8px
---

# my_app — Design Tokens

## Overview

**简洁现代（Clean & Modern）**：这是一个个人工具箱应用的视觉基调。设计原则是
「工具感优先，装饰最少化」——界面安静、信息密度适中、交互反馈清晰，
让内容和功能说话，而不是视觉效果。

视觉体系与 **shadcn/ui（zinc 色系）同源**：黑白灰近单色、无彩色强调。
风格统一与简约是硬要求：任何新页面、新组件都应从本文件取值，
不允许出现"随手写的颜色/圆角"。个别功能页面（如机器人眼睛）可以在
自己的画布内做个性化表达，但导航、按钮、列表等公共层必须遵循本规范。

## 设计价值观（宪法，2026-11-10 登记）

评价任何设计决策的最终标准。**shadcn 的「Beautiful Defaults / 组合优于定制 /
克制」为方法论基准**，结合本产品审美定三条：

1. **克制**：黑白灰是基调，黑即强调（不引入彩色强调）；能做但想清楚了不做
   （Ant「保持克制」同款裁决）；每加一个新样式先问「删掉会怎样」。
2. **精密**：工程感优先——数据大而硬（display 大数字）、数字等宽（tabular）、
   比例来自公式不来自手感。信息密度服务使用，不服务「显得满」。
3. **组合不发明**：页面由既有组件变体组合而成，不为单页发明新样式；布局选
   「页面模式」预设（见下），不为单页发明新构图。

裁决示例：两个方案难分时，选更「安静」的那个；需要强调时靠字重与留白，
不换色相（唯一例外：error 红仅限错误/危险）。

## Colors

全组色值与 `ShadZincColorScheme.light()` 默认值逐一对齐（shadcn 是源头，本文件是登记处）：

- **Primary (#18181B):** shadcn zinc-900 近黑——唯一强调色，只用于交互：
  主按钮、选中态、焦点环。**不使用彩色强调**（黑即强调）。
- **Secondary (#71717A):** 次要文字与非激活图标（shadcn mutedForeground）。
- **Neutral (#FFFFFF):** 页面底色（shadcn background，纯白）。
- **Surface (#FFFFFF):** 卡片、输入区的表面色——与页面底同色，
  **分层改由 1px 描边（border #E4E4E7）+ 字重表达**（shadcn 的分层策略）。
- **On-surface (#09090B):** 主文字与主要图标（shadcn zinc-950 近黑）。
- **Border (#E4E4E7):** 卡片与容器描边（shadcn border）。
- **Error (#DC2626):** 仅用于错误与危险操作的**文字/图标**（red-600 档，
  白底 4.5:1 过 AA）；危险按钮底色由 shadcn destructive 提供（red-500）。

## Typography

使用系统默认字体（`system-ui`：Windows 上 Segoe UI / macOS 上 SF Pro /
手机上系统字体），不引入自定义字体，保证各端原生观感与零加载成本。

- **h1 (1.75rem/700):** 页面标题，每页至多一个。
- **display (2.25rem/600):** 仪表盘数据大数字（stat-block 专用），每卡至多一个。
- **body-md (1rem/400):** 正文与列表主文本。
- **label-sm (0.8125rem/500):** 说明文字、标签、状态提示——次要信息专用。

## 比例与公式（2026-11-10 登记）

设计决定来自公式，不来自手感（「精密」价值观的机械面）：

- **字阶模数**：1.25 倍级 —— label-sm 13 → body-md 16 → h1 28（≈1.25³）→
  display 36；新字阶只能落在模数位（13/16/20/25/31/39…），不取中间值。
- **字重三档封顶**：400（阅读）/ 500（UI 标签）/ 600-700（标题）。不使用其他
  字重做层次（层次靠字号与留白）。
- **字距公式**：display/h1 字距随字号负向收紧（fontSize × -0.02 取负 px），
  16px 及以下字距为 0；任何文本不得正字距。
- **留白节奏**：8pt 网格；区块间距 24（lg）↔ 40（新档 xl=40，区块间大跳），
  组件内间隙 4/8/16；相邻区块间距 ≥ 组内间距 × 2（亲密性：近=同组）。
- **圆角派生**：sm 6 / md 10 / lg 16 为基；徽章/胶囊 = 9999px；进度条 = 全圆；
  不引入其他圆角值。
- **对比度**：正文对背景 ≥ AA；辅助文字（secondary）只用于次要信息。

## Layout

### Responsive（2026-11-09 登记）

三档断点（视口宽度，取值来自 `AppBreakpoints`，页面经 `AppLayout.of(context)` 判断）：

- **compact（< 600px，手机）**：单列布局；数据卡网格 2 列（`Wrap` 自动换行）。
- **medium（600–1024px，平板/分屏）**：内容区限宽 720px 居中；数据卡网格 3 列。
- **expanded（> 1024px，桌面/网页）**：内容区限宽 900px 居中（一屏信息不过宽）；
  复杂管理页可用 `ShadResizable` 侧栏 + 主区双栏形态。

规则：断点只影响**布局形态**（列数/限宽/分栏），不影响字号与间距（字阶与 8pt
网格跨档一致）；任何页面在 320px 窄屏不得横向溢出。

- 采用 **8pt 网格**：`spacing.sm=8px`（元素内间隙）、`md=16px`（组件间距）、
  `lg=24px`（区块间距）。
- 页面左右留白 16px；列表类页面用整宽行 + 分隔线（1px，border 色），不套卡片。
- 导航层级浅：列表 → 详情/工具页，两级为止，桌面端工具页带返回标题栏。

## Elevation & Depth

**克制**：默认无阴影。层级靠 1px 描边（surface 卡片的 border）与字重表达；
仅弹层（菜单、对话框）允许一档轻阴影。不使用玻璃拟态、渐变、发光。

## Shapes

- **rounded.sm (6px):** 小型内嵌元素（标签、状态徽标）
- **rounded.md (10px):** 按钮、输入框
- **rounded.lg (16px):** 卡片、弹层

## Components

**组件层实现 = shadcn_ui**（`shadcn_ui` 包，Agent Skill 文档在 `.agents/skills/`）：
shadcn 组件直接使用 `ShadZincColorScheme` **完全默认值（零覆盖）**；
Material 组件经 `ShadApp.custom` 映射层与 shadcn 同源，
本文件 tokens 只为 Material 侧与自建壳供值（值与 shadcn 同一调色板）。
shadcn 未提供的"壳"（标题栏/列表行/分节）用 `lib/design/widgets/` 自建，同样只吃 tokens。

- `button-primary` → `ShadButton`（primary 变体）：黑底白字，一屏唯一的高强调动作，
  其余动作用 `.secondary` / `.outline` / `.ghost` / `.link` 弱化变体。
- `card` → `ShadCard`：白卡 + 1px border 描边；成组信息容器，能用列表行就不用卡片。
- `list-tile` → 自建 `AppListTile`：图标块 + 标题 + 副标题 + 箭头，
  悬停/按压反馈齐全（shadcn 无独立列表行组件）。
- `icon-block`：列表行与身份区的图标底色块（primary 10% 淡底 = #E8E8E8 灰底 +
  primary 图标），是入口图标的统一容器。
- `input-field` → `ShadInput` / `ShadTextarea`：聚焦描边走 primary。
- 图标 → **Lucide**（`LucideIcons.*`，经 shadcn 导出）：全应用统一，
  不再使用 Material Icons 字体（避免图标字形渲染问题）。
- `text-caption`：辅助文字统一走 secondary 色 + label-sm 字号。
- `status-error` → `ShadButton.destructive` / `ShadTheme.colorScheme.destructive`。
- `stat-block`（仪表盘数据卡，2026-11-09 登记）：大数字 + 标签的统计单元。
  数字用 `display` 字号 + `w600` 字重（onSurface），标签用 `text-caption` 规格
  （secondary + label-sm）；多卡横排等宽网格（2~3 列，间距 `AppSpacing.md`），
  卡体白底 + 1px border（`card` 同规格）。数字后可带单位小字（secondary）。
- `status-badge`（状态徽章，2026-11-09 登记）：运行态/模式指示。胶囊形
  （radius 全圆角），常态 = primary 10% 淡底 + primary 文字（icon-block 同源）；
  异常态 = error 12% 淡底 + error 文字（red-600）；中间态（进行中）= secondary
  10% 淡底 + secondary 文字。左侧可带 6px 圆点（同文字色）。**不引入新色相**。
- `progress-bar`（进度条，2026-11-09 登记）：确定进度用线性条（4px 高、
  radius 全圆、轨道 = border 色、填充 = primary），不确定进度用同规格呼吸条；
  进度数字用 `text-caption` 随行显示。
- `action-row`（操作按钮排，2026-11-09 登记）：一屏操作区的按钮布局——
  主操作（启动/安装类）用 `ShadButton` primary（一屏唯一），次操作（停止/重装）
  用 outline 变体排一行；危险操作（重置/删除）用 ghost + error 文字（红文字
  白底 AA），与主排分行或尾随文字钮，不与主按钮并列抢焦点。
- **交互态**：hover = 主文字色 4% 覆盖，pressed = 8% 覆盖（派生色，不引入新色）；
  所有可点击容器（列表行、卡片、按钮）必须带悬停/按压反馈。

## 组件变体矩阵（2026-11-10 登记）

统一感的机械来源（shadcn cva 模式）：每个交互组件 = `variant × size × state`
显式矩阵，**加样式=加矩阵键，不是改样式**。Flutter 侧对应 widget 的命名参数。

**通用 state 三档**（所有交互件）：default / hover（主文字色 4% 覆盖）/
pressed（8% 覆盖）+ disabled（40% 透明度，不换色）。

| 组件 | variant（横） | size（纵） | 备注 |
|---|---|---|---|
| `AppButton` | primary（黑底白字，一屏唯一）· outline · ghost · danger（红字） | sm（28h）· md（36h） | 每屏 primary ≤ 1 |
| `AppChip`（徽章） | solid-tint（淡底）· outline · dot（圆点） | sm · md | 状态语义：normal=primary 淡底 / busy=secondary / error=red |
| `AppStatBlock` | plain | sm（display 25）· md（display 36） | 数字+单位+标签 |
| `AppListTile` | leading-icon · leading-label（首字母） | sm · md | 尾随区可挂按钮/开关 |
| `AppInput` | outline · filled | sm · md | 聚焦描边走 primary |
| `AppProgressBar` | determinate · indeterminate | thin（4px） | 轨道 border 色 |

新组件入册流程：先登记本表（含三态）→ DESIGN.md 前端 YAML 登记 → 实现进
`lib/design/widgets/` → 组件库页展示示例（正误对照）。

## 页面模式（构图预设，2026-11-10 登记）

布局不为单页发明（Hermes layout 预设同款思路）：页面构图只能选以下预设——

1. **仪表盘模式**（系统/监控类）：状态 Hero（badge+版本行）→ stat 网格
   （Wrap，compact 2 列/宽 3 列）→ 操作排（action-row）→ 详情区。
   一屏一个主操作；数据用 display 大数字；正例=Linux 底座页。
2. **列表模式**（内容集合）：筛选/搜索行（可选）→ 列表（AppListTile 竖排，
   分组用 AppSection）→ 空状态（见模式 4）。
3. **设置模式**（开关/配置）：分组（AppSection）→ 行（tile + 尾随控件）；
   危险操作置底分组。
4. **空状态模式**：图标块 + 一句说明（label-sm）+ 一个引导按钮（primary）；
   不许一句话打发（正误对照：✗ '暂无数据' 一行字 / ✓ 图标+说明+「创建」按钮）。

## Do's and Don'ts

- **Do** 从本文件取色取值；新组件先在 `components:` 登记再使用。
- **Do** 保持留白与对齐的一致性（8pt 网格），信息层级靠字重与留白拉开。
- **Don't** 引入彩色强调色（本体系以黑为强调）；需要弱强调时用透明度/字重，不换色相。
- **Don't** 使用大面积渐变、发光、重阴影、动效装饰——动画只用于状态过渡
  （150~300ms，ease-out）。
- **Don't** 在公共层（导航/按钮/列表）使用功能页的个性化视觉语言。

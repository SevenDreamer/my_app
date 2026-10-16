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
typography:
  h1:
    fontFamily: system-ui
    fontSize: 1.75rem
    fontWeight: 700
    lineHeight: 1.25
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
- **body-md (1rem/400):** 正文与列表主文本。
- **label-sm (0.8125rem/500):** 说明文字、标签、状态提示——次要信息专用。

## Layout

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
- **交互态**：hover = 主文字色 4% 覆盖，pressed = 8% 覆盖（派生色，不引入新色）；
  所有可点击容器（列表行、卡片、按钮）必须带悬停/按压反馈。

## Do's and Don'ts

- **Do** 从本文件取色取值；新组件先在 `components:` 登记再使用。
- **Do** 保持留白与对齐的一致性（8pt 网格），信息层级靠字重与留白拉开。
- **Don't** 引入彩色强调色（本体系以黑为强调）；需要弱强调时用透明度/字重，不换色相。
- **Don't** 使用大面积渐变、发光、重阴影、动效装饰——动画只用于状态过渡
  （150~300ms，ease-out）。
- **Don't** 在公共层（导航/按钮/列表）使用功能页的个性化视觉语言。

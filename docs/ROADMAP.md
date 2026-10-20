# my_app — 路线图

> 状态：草案 v0.1（2026-10）｜原则：每阶段独立可交付、可体验；
> 阶段内条目可按需调整顺序，阶段之间不轻易并行。

## Phase 0：主题与框架落地（当前）🎯

**目标**：把"简洁现代"的设计落到代码，功能框架成型，两端可打包分发。

- [ ] `DESIGN.md` tokens → Flutter `ThemeData`（色彩 / 字体 / 圆角 / 间距的唯一入口）
- [ ] 公共组件基调统一（标题栏 / 按钮 / 卡片 / 列表 / 输入框）
- [ ] 功能注册机制固化（`HomePage._FeatureEntry` → 带平台能力声明的可扩展注册表）
- [ ] 平台能力声明落地（移动端 / 桌面端各自显示可用功能）
- [ ] 打包发布：Windows 安装包 + Android APK（正式签名）

**验收**：新页面随手写就是统一风格；两端都能安装运行；
机器人眼睛等个性页面与公共层视觉互不干扰。

## Phase 1：设备通信打通

**目标**：两台手机通过蓝牙 / Wi-Fi 互相发现并收发消息。

- [ ] 蓝牙 BLE：广播、扫描、配对、GATT 通信
- [ ] Wi-Fi：局域网发现（mDNS）与直连
- [ ] 统一消息协议：帧格式、握手、可靠传输、版本协商
- [ ] 通信调试页：收发日志、信号强度、延迟

**验收**：两台手机互通文本消息（蓝牙与 Wi-Fi 各一条链路）。

## Phase 2：内容聚合

**目标**：内容能"流进来"，成为个人资料的入口。

- [ ] 系统分享接收：分享到 my_app → 落库（配合笔记板块）
- [ ] GitHub / 博客查询模块
- [ ] 微信生态联动探索（小程序 / 公众号的可行形态）

**验收**：从至少两个外部 App 分享内容进来并可检索。

## Phase 3：组网与控制

**目标**：多设备成网，设备之间可互相控制。

- [ ] 多设备组网：拓扑管理、成员发现、消息路由
- [ ] 手机控手机：指令通道、输入事件转发（基础操作）
- [ ] 桌面控手机：控制端 UI（连接管理、指令面板）

**验收**：三台设备组网内互通；桌面端对手机执行至少一条基础指令。

## Phase 4：AI 与 MCP 基础

**目标**：为 agent 接入铺好协议层。

- [ ] MCP 协议层：工具注册、能力描述、调用通道
- [ ] agent（小七）接入实验：通过 MCP 调用 App 内能力

**验收**：外部 agent 能发现并调用至少两个 App 内工具。

## 未排期想法池

- **无缝回调授权（Authorization Code + Loopback redirect）**：app 内起本地
  小服务器（`http://127.0.0.1:<固定端口>/callback`），浏览器授权完 redirect 回它
  ——省掉 device flow 的轮询等待。**触发条件**：① 有了自己的域名（可走 App Links
  最优雅）或 ② 对 5 秒轮询等待确实不满。**动手前先验证**：GitHub OAuth App 是否
  接受 loopback 回调地址（RFC 8252 原生应用标准推荐此法）。参考库：`oauth2_client`。
- ⌘K **命令面板**（shadcn `command` 组件的桌面形态）：全局快捷键唤起，
  模糊搜索功能直达——桌面工具箱的效率杀器
- **GitHub 流水线监控**：App 内查询 dev-release 流水线状态；流水线开始 / 完成 /
  异常时推送通知（聚焦版本发布相关，通知带版本号、run 链接、失败摘要）。实现思路：
  GitHub webhook（`workflow_run` 事件）推送为主 + 轮询 Actions API 兜底；授权复用
  `lib/app/update/github_auth_service.dart`（scope 需含 `repo` 或 `public_repo`）。
  **依赖/触发条件**：① GitHub OAuth 已落地（近期 webview 授权可用）；② 推送通道
  可走设备直连（Phase 1 通信打通后），或先用系统本地通知（仅前台/轮询时触发）。
  **动手前先验证**：OAuth App 的 scope 能否读 Actions run 状态；webhook 需要一个
  公网可达的接收端（家用 Mac + frp / 云函数皆可）
- **kbd 快捷键提示组件**：机器人眼睛页（1~8 表情/空格）等键盘操作的标准提示样式
- **暗色主题**：照 shadcn dark-mode 指南切（zinc dark 值在 shadcn_ui 包内自带），
  需要 DESIGN.md 增补暗色组 + theme.dart 出 `shadDark`——参考 https://ui.shadcn.com/docs/dark-mode
- Dart primary constructors 语法迁移（门槛：pubspec sdk 下限升 `>=3.13.0` + `.fvmrc`
  的 Flutter 3.41.9/Dart 3.11 升到 3.47+/Dart 3.13，否则语法不可用；
  见技能 `dart-use-primary-constructors`，首个目标类 `_HubSink`）
- 数据库管理工具（浏览 / 查询 / 备份本地库）
- NFC 触碰配对（碰一碰建连）
- 更多工具：时钟、天气、系统监控、剪贴板同步
- 机器人眼睛：Rive 风格样式、摄像头眼动（移动端）

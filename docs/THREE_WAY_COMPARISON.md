# 三方对比：DSHA ↔ dsh-go ↔ my_app（2026-11-04）

> 定位一句话：**DSHA** = DSH 的「运行环境管理器」（装环境、管容器）；
> **dsh-go** = DSH 的「完整手机客户端」（官方功能全原生化 + 桌宠 + 市场）；
> **my_app** = 个人工具箱（DSH 系统为一域）+ 自有分发/热更/诊断体系。
> 合规：DSHA=MIT（全量搬码可用）；dsh-go=**AGPL-3.0 只学设计不抄码**（sdk/+examples/ MIT 除外）。

## 一、技术架构

| | DSHA | dsh-go | my_app |
|---|---|---|---|
| 技术栈 | Android 原生 Java | **Flutter 3.47 + Riverpod 3 + Kotlin** | Flutter + shadcn + **Rust** + Kotlin |
| DSH 运行时 | proot + rootfs（Java 管理） | Ubuntu 24.04 + Node + dsh 经 proot（Kotlin 管理） | 同路线（Dart 管理 + Rust 解包） |
| proot 可执行 | lib*.so + useLegacyPackaging | **同款**（lib*.so + useLegacyPackaging） | 同款（三项目共识做法） |
| 绕 W^X | nativeLibraryDir | **targetSdk=28**（避 Android 10+ 限制） | nativeLibraryDir（不动 targetSdk） |
| 执行通道 | Root/Shizuku/ADB 三通道 | 免 Root（proot 直跑，无特权通道） | Shizuku（已通）/Root/ADB |
| 状态管理 | —（原生） | Riverpod | ChangeNotifier MVVM |
| 分发 | GitHub Release | GitHub Release + 国内镜像 | **R2 manifest + Shorebird 热更** |
| 运行时资产 | APK 内 assets | abi 风味分包（arm64/x64） | 全量烘 APK（277MB） |

## 二、功能全景

| 功能 | DSHA | dsh-go | my_app |
|---|---|---|---|
| DSH 环境安装 | ✅ 六步 | ✅（安装器+事件流） | ✅ 六步（真机全绿） |
| DSH 对话/会话 | ❌（网页兜底） | ✅ **全原生**（对话/排队/插话/待办/斜杠命令/模型/文件） | ⬜（Hermes 域另一线） |
| 虚拟屏/手机操控 | ✅ core 全件 | ✅（读屏/点按/输入） | ✅ 全件齐备（待点亮） |
| 插件市场 | ✅（dsh-plugin） | ✅ **market/ 原生面板**（JSON 视图声明） | ⬜（ROADMAP） |
| 遥控电脑 | ❌ | ✅ SSH/DSH Remote | ⬜（设备互联手柄另一线） |
| 备份 | ✅ ~80 类 | ❌ | 🔶 搬码入包（待接线） |
| 终端 | ✅（termux） | ❌ | ⬜（termux GPL 豁免） |
| Web 浏览器 | ✅ 内嵌 | 🔄 WebView 兜底 | ⬜ |
| 桌宠 | ❌ | ✅ Deepy/鲸娘（App 外显示） | ❌（robot_eyes 是另一形态） |
| 诊断 | 本地 | 日志流（脱敏+seq） | ✅ **Sentry 远程聚合**（超两家） |
| 热更 | ❌ | ❌ | ✅ **Shorebird**（超两家） |
| i18n | ✅ | ✅（l10n） | 🔶 中文优先 |

## 三、关键逻辑/流程对比

### 3.1 运行时生命周期（三家共识 + 差异）
- **共识**：APK 带 rootfs 资产 → 解包 → proot 起容器 → 跑 Node/dsh。
- dsh-go 的平台通道设计最完整：`dsh/runtime`（getStatus/install/start/stop/getLogs/reset）
  + `EventChannel` 事件流（进度/状态/日志三类；日志 **seq 递增不漏行**协议）——
  **我们的诊断日志面可参考此设计**（只学设计）。
- dsh-go 用 **targetSdk=28 绕 exec 限制** vs 我们/DSHA 用 nativeLibraryDir——
  我们的选择更面向未来（targetSdk 提升不破）。

### 3.2 虚拟屏/手机操控
- DSHA：core 独立进程（app_process）+ VirtualDisplay + 握手/传输/策略——最重的工程化
  （策略校验/三态退出码/观测账本）。
- dsh-go：面向用户的功能面（读屏/点按）——实现细节较轻。
- my_app：**DSHA 契约全量搬码**（含策略/握手）——行为契约最保真。

### 3.3 插件
- DSHA：dsh-plugin 命令行市场。
- dsh-go：**JSON 视图声明**（「App 用自己的组件画出来，不执行插件的任何代码」）——
  **安全设计亮点**（声明式 UI 隔离），F3 插件 UI 值得参考此模式。
- my_app：未开始（DSH 插件市场保留决策已在 ROADMAP）。

## 四、dsh-go 值得学的设计（只学设计，AGPL 红线）

1. **EventChannel 事件协议**（seq 不漏行 + 脱敏）——诊断/日志面。
2. **插件 JSON 视图声明**（声明式渲染隔离）——F3 插件 UI。
3. **纯 Dart 客户端包**（`dsh_client` 无 Flutter 依赖可单测）——我们的 dsha_core 同思想 ✓。
4. **官方功能对齐表**（official-parity.md 逐项核对法）——功能完备性管理。
5. Riverpod 状态管理与玻璃质感 UI（审美参考——我们 shadcn 路线不动）。

## 五、my_app 的差异化定位（不与两者正面竞争）

- **工具箱定位**（DSH 是其中一域）vs 两家都是「DSH 专用客户端」。
- **工程化底座优势**：Rust 解包、Shorebird 热更、R2 免授权分发、Sentry 远程诊断——
  两家都没有的生产级链路。
- **契约保真**：DSHA 的行为契约（错误代号/策略/三态）逐字保留——与官方 DSH 语义最一致。
- 虚拟屏线与 DSHA 同深度（core 全件）；DSH 对话线可走 Hermes 域（自己的 agent 形态）。

## 六、规模参考

| | 代码量 |
|---|---|
| DSHA | 593 Java 类（~10 万行级） |
| dsh-go | 1,741 Dart 文件 / **90,783 行** + 300 Kotlin |
| my_app | Flutter/Dart ~7 万行级 + Rust + 搬码 Java 585 件 |

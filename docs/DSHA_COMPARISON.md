# DSHA ↔ my_app 功能与逻辑对比（2026-11-04）

> 目的：功能/逻辑级对照（不是代码 diff）——DSHA 能干什么、我们对应什么形态、
> 缺什么、整个项目的流程怎么走。基线 `98bd97a`（MIT）。

## 一、DSHA 全功能面（从代码域反推）

| 功能域 | DSHA 的能力 | 代码规模 |
|---|---|---|
| **DSH 运行环境** | App 内装 Linux rootfs + Node/pnpm/Python/dsh 六步工具链，proot 容器执行 | runtime/ ~50 类 |
| **虚拟屏** | 独立 core 进程（app_process）管理 Android VirtualDisplay——预览/触控/手势/语义树/锚点/截图 | vscreen/ 20 类 |
| **执行通道** | Root/Shizuku/ADB 三受管通道（「不得退化成任意 shell」策略） | bridge/ + ShizukuShell |
| **备份系统** | 自动备份/便携导出/恢复/加密/快照/插件备份图 | backup/ **~80 类**（最大域） |
| **插件市场** | dsh-plugin 安装/恢复/激活钩子/输出隔离 | core/Plugin* ~10 类 |
| **Web 浏览器** | 内嵌浏览器对话/上传下载/全屏/麦克风/画中画 | ui/Web* + core/Web* ~30 类 |
| **终端** | PTY 终端 tab（termux terminal-view） | Pty* + Terminal* |
| **恢复系统** | 环境重建/修复代理/启动恢复 | recovery/ 6 类 |
| **更新引擎** | GitHub Release 更新/下载服务 | core/Update* |
| **局域网** | LAN 认证/代理服务/令牌 | Lan* 8 类 |
| **设备桥** | 设备信息/短信授权/剪贴板/文件操作 | bridge/ + DeviceShellPolicy |
| **Agent 任务** | 后台任务通知/停止 | AgentTask* |
| **诊断** | 诊断仓库/日志/历史/脱敏导出 | diagnostics/ + core/Diagnostic* |

## 二、我们（my_app）的对应形态

**架构差异**：DSHA = Android 原生（Java）；my_app = **Flutter（编排/UI）+ Rust（系统面）+
Dart（逻辑）+ Kotlin（通道/系统服务）**。原则：编排↔Dart、系统面↔Rust、行为契约逐字。

| 功能域 | 我们的形态 | 状态 |
|---|---|---|
| DSH 运行环境 | **Dart 重写**（install/ 六步）+ Rust 解包 + proot 容器 | ✅ **真机六步全绿** |
| 虚拟屏 | Manager/传输/握手 **Dart 化** + core 本体 **Java 搬码** + Flutter 预览页 | ✅ 全件齐备（点亮待验） |
| 执行通道 | **Shizuku Kotlin 通道**（UserService）+ Root/ADB 通道待接 | ✅ Shizuku 真机全通 |
| 备份系统 | **Java 全量搬码已入包**（~80 类） | 🔶 编译收尾中，UI/接线未做 |
| 插件市场 | 未开始（ROADMAP Phase 后段） | ⬜ |
| Web 浏览器 | 未开始（ROADMAP） | ⬜ |
| 终端 | stub 契约壳（termux 库 GPL 传染+公共仓无件） | ⬜ 后置 |
| 恢复系统 | 未开始 | ⬜ |
| 更新引擎 | **自己的更新链**（R2 manifest + Shorebird 热更 + GitHub prerelease） | ✅ 生产在用 |
| 局域网 | 未开始 | ⬜ |
| 设备桥 | DeviceShellPolicy/Executor **已搬码**（argv 策略契约） | 🔶 执行面在 |
| 诊断 | **Sentry 体系**（MY-APP-3/5 诊断包 + logcat 取证 + 启动崩溃捕获） | ✅ 超原版（原版无远程聚合） |

**另外我们有 DSHA 没有的**：Shorebird 热更、R2 免授权分发、Sentry 远程诊断、
Flutter 跨端 UI（桌面互补）、Rust 硬化解包（ANR 修复）、Hermes/手柄/笔记等工具箱功能。

## 三、核心流程对比

### 3.1 DSH 环境安装流程（一致，逐字契约）
```
资产暂存(rootBundle) → Rust 后台解包(ANR 修) → proot 容器定位(nativeLibraryDir, W^X)
→ 六步工具链(bash/curl+git+Python/Node/pnpm/dsh/补丁链) → 诊断上报
```
真机实证：`steps: 1:ok…6:ok` 全绿（dev.26+70 Patch 8）。

### 3.2 虚拟屏启动流程（全量搬码后与原版一致）
```
VM.boot → Shizuku 授权(弹窗/60s 超时) → UserService 绑定(binder→ShellService)
→ manager.start → DeviceShellExecutor.executeVirtualScreen(uid/identity/argv 策略)
→ app_process 加载 VirtualScreenCore → core 起 → stdout 握手串
→ manager 解析握手(VscreenHandshake.started) → create 虚拟屏 → 帧轮询 → 预览
```
卡点史：Provider 类名→boot UUID→journal POSIX→绑定时序→R8 keep→握手解析→
readLine EOF→argv 契约——**每层已修**，全量搬码后待真机终验。

### 3.3 命令执行契约（一致，「不得退化成任意 shell」）
- `DeviceShellPolicy.inspectManagedVirtualScreen`：单条 argv 策略校验
- uid ∈ {0(root), 2000(shell)} 才可执行虚拟屏启动
- 输出带 `[EXIT=0]` 后缀判定完整性；124 可重试 / 125 结果未知 / 126 策略拦截

## 四、缺什么（功能差集）

**未做但规划内**：插件市场、Web 浏览器、终端、恢复系统、局域网、备份 UI/接线。
**已做且超原版**：热更/分发/诊断/跨端/Rust 化。
**注意**：备份 ~80 类已搬码进包（行为契约保真）——差 UI 与 Flutter 接线。

## 五、合规台账

- DSHA（MIT）：逐文件归因头 + THIRD_PARTY_NOTICES
- proot 全家桶（GPL-2.0/LGPL-3.0）：许可证全文随包
- Shizuku api/provider（MIT）：依赖引用
- gson/snakeyaml/bcprov/appcompat/webkit/material（各自许可证）：依赖引用
- termux terminal-view：**不引入**（GPL 传染 + 公共仓无件）→ stub

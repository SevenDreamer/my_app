# 安卓 Hermes 客户端（my_app）设计总览 —— 对标 Hermes Desktop

> 状态：v0.1 草案（2026-10-27）
> 前置：`MOBILE_HERMES_BLUEPRINT.md`（移动 Hermes 蓝图）、`VISION.md`、`ROADMAP.md`
> 依据：Hermes 官方文档（llms.txt 功能索引 + Desktop / Multi-Connection / Webapp 页）与官方仓库
> 本页只管 **GUI 客户端**（怎么做 UI）；运行时（内置 Ubuntu / Termux）与安全层见蓝图 M-A

## 0. 一句话定位

**my_app 的「Hermes」域 = Hermes Desktop 的安卓对应物**：不重写 Hermes 核心（Python），
走同一套 gateway 协议（HTTP + WebSocket + token/OAuth），用 Flutter 做移动优先的原生 UI。
运行时后置：先连 PC/Mac/远程 gateway 验收，后接 Termux / 内置 Ubuntu（DSHA 式）本地核。

## 1. 钉死的三个边界（先于一切 UI）

| 边界 | 结论 | 依据 |
|---|---|---|
| 核心 | **不重写**。Hermes 核心是 Python（CLI/gateway/agent），Desktop 只是 Electron 壳 + web 前端 | 官方：Desktop "uses the same Hermes Agent core and settings" |
| 协议 | **gateway HTTP + WebSocket**，鉴权 = session token / OAuth；连接注册表四型：Local / Remote gateway / SSH / Hermes Cloud | Multi-Connection Desktop 页："each registered gateway dials its own backends and WebSockets on demand" |
| 语言 | **Dart/Flutter 为主体**（复用 my_app 四层与设计体系）；Rust 只做可选 sidecar（本地 WS 中继 / ADB 桥 / 进程管理，`rust/` workspace）；webapp bundle 只当垫脚石不当终态 | 方案取舍（本会话 2026-10-27） |

### 1.1 协议侦察清单（G0 交付物，动手前完成）

> 📄 成果已成文：**`docs/HERMES_GATEWAY_PROTOCOL.md`**（276 方法 / 65 事件全量清单 + 鉴权三型）。

- [x] gateway WS 端点与握手（`/api/ws`、NDJSON-RPC、`gateway.ready`、三型鉴权）
- [x] 消息 schema（事件面 65 个全量在册；字段级抄录随 G1 补）
- [x] 会话生命周期（`session.*` 40 个方法面在册）
- [x] 管理面 API（config/secrets/mcp/plugins/cron/kanban…全量在册）
- [ ] 流的重连/背压/字段级细节 —— 余项见协议清单 §7
- [x] 参考实现定位（`tui_gateway/` + `contracts/` + `apps/shared/gateway-events.ts`）

## 2. 功能面清单（对标官方功能全集）

优先级：**P0** = 聊天最小闭环必备 ｜ **P1** = Desktop 对齐 ｜ **P2** = 管理面/长尾 ｜ **M** = 移动端增量

### A. 连接与后端管理

| 功能 | 说明 | 优先级 |
|---|---|---|
| 连接注册表 | 命名多连接；Local（内置运行时）/ Remote gateway（HTTP(S)）/ SSH / Hermes Cloud | P0（先 Remote） |
| 鉴权 | session token、OAuth、一次性签名链接兑换 | P0 |
| 多实例并行 | 侧栏连接切换；后台流不断线 | P1 |
| 连接健康/诊断 | 断线重连、延迟、版本显示 | P1 |

### B. 聊天与会话（主界面）

| 功能 | 说明 | 优先级 |
|---|---|---|
| 流式对话 | token 流式渲染、markdown、代码高亮、LaTeX | P0 |
| 工具调用卡 | 流式工具输出、折叠详情、审批提示（dangerous command） | P0 |
| diff / 补丁展示 | patch 的 unified diff 渲染 | P1 |
| Artifacts | Deliverable Mode：图表/PDF/表格当附件卡片 | P1 |
| Context References | `@` 引文件/文件夹/diff/URL 进消息 | P1 |
| 图片/视觉 | 附件、粘贴图片、vision 结果展示 | P1 |
| 输入条 | 多行、附件、语音按钮、斜杠命令、停止/继续生成 | P0 |
| 会话内导航 | 消息跳转、复制、重试、编辑重发 | P1 |

### C. 会话管理

| 功能 | 说明 | 优先级 |
|---|---|---|
| 会话列表 | 按 profile/平台分组、搜索（FTS）、恢复 | P0 |
| Session Heartbeats / Loops / Goals | 周期唤醒、循环、常驻目标 | P2 |
| 会话配对/迁移 | 跨表面共享同一会话队列 | P2 |

### D. 执行面（agent 干活时看得见、管得住）

| 功能 | 说明 | 优先级 |
|---|---|---|
| 审批流 | 危险命令确认、approval mode 显示 | P0 |
| Checkpoints & Rollback | 破坏性操作的快照/回滚提示 | P1 |
| Delegation | 子 agent 并行任务卡（delegate_task） | P1 |
| Cron 任务 | 自然语言调度、列表/启停 | P1 |
| Kanban | 多 agent 任务板 | P2 |
| Code Execution / Batch | 高级执行面 | P2 |

### E. 资源管理

| 功能 | 说明 | 优先级 |
|---|---|---|
| 文件浏览器 | 主机文件树、查看/下载 | P1 |
| Git review | diff 审阅（Desktop workspace 有） | P2 |
| 预览 | side-by-side 预览（网页/图表/文档） | P1 |
| Skills 管理 | 列表/详情/Hub 安装/Curator 状态 | P1 |
| Memory 管理 | MEMORY.md/USER.md 编辑、session search、providers | P1 |
| 人格文件 | SOUL.md / AGENTS.md 编辑（Personality） | P2 |

### F. 设置与配置

| 功能 | 说明 | 优先级 |
|---|---|---|
| 模型/Provider | 切换模型、provider、凭据池状态 | P0 |
| config 编辑 | config.yaml 分区编辑（勿手改的红线） | P1 |
| Secrets/Vault | 凭据库、密码填充（Passwords & Logins） | P2 |
| Profiles | 多 agent 档案、profile 分发 | P1 |
| MCP / Plugins / Catalog | 服务器管理、插件安装（manage_catalog 同款） | P1 |
| Hooks / Language packs / Skins | 扩展面 | P2 |
| Managed Scope | 管理员钉住配置的显示 | P2 |

### G. 语音与输入

| 功能 | 说明 | 优先级 |
|---|---|---|
| Voice Mode | 实时语音对话 | P1 |
| TTS / 转写 | 语音消息 | P1 |
| Wake Word | "Hey Hermes" | M/P2 |

### H. 消息平台与自动化

| 功能 | 说明 | 优先级 |
|---|---|---|
| Messaging 配对 | 21+ 平台的接入状态/配对引导 | P2 |
| Webhooks | GitHub 等事件触发 | P2 |
| Bot Mode / Bot Screen | 机器人名册、群聊 | P2 |

### I. 系统面（移动端壳）

| 功能 | 说明 | 优先级 |
|---|---|---|
| 通知中心 | agent 完成/审批请求/定时任务 → 系统通知 | **M/P0** |
| 后台与电池 | 前台服务/唤醒策略（对齐 DSHA 看门狗思路） | M/P1 |
| 悬浮窗/画中画 | 常驻迷你窗（蓝图 M-C4 / Termux:Float 参考） | M/P1 |
| Live2D 壳 | 桌宠化表情反馈（蓝图 M-C，情绪引擎） | M/P2 |
| 深链/分享入口 | 系统分享进消息、快捷 tile | M/P2 |
| 生物识别锁 | 打开 app/查看凭据需验证 | M/P2 |

## 3. 页面/导航结构（UI 设计清单）

```
AppShell（底部导航 + 会话抽屉）
├── 连接页（connections 注册表；新增/编辑/诊断）
├── 会话列表页（搜索/分组/新建）
├── 会话页 ★主界面
│   ├── 消息流（markdown/工具卡/diff/artifact 卡/附件）
│   ├── 输入条（附件/语音/斜杠命令/停止）
│   └── 会话面板（模型/审批模式/工具集/心跳设置）
├── 命令面板（全局 ⌘K 等价：搜索会跳/命令/文件）
├── 文件/预览页（树 + 查看器 + side-by-side）
├── 任务页（Cron / Delegation / Kanban 标签）
├── 资源页（Skills / Memory / 人格文件）
├── 设置页（Provider/模型、config、Secrets、Profiles、
│            MCP/Plugins、通知、外观、语音、关于）
└── 移动壳（通知中心、悬浮窗、Live2D 层——独立开关）
```

### 3.1 落位到 lib/ 四层（AGENTS.md 架构铁律）

- 新域 `features/hermes/`（真·能力）：连接管理、会话、聊天页、任务、资源、设置；
  内聚参照 robot_eyes：`pages/` `widgets/` `view_models/` `models/`；
- `data/services/`：gateway 客户端（WS/HTTP、鉴权、重连）——**服务经构造函数注入 VM**（MVVM 铁律）；
- `app/feature_registry.dart` 登记「Hermes」条目（平台能力：mobile full / desktop limited 先行）；
- `design/`：消息流/工具卡/代码块等新组件进 `design/widgets/`，只吃 tokens；
- `packages/`：若 gateway 协议层可独立，做 `packages/hermes_gateway/`（类比 hid_gamepad）。

### 3.2 页面设计细案（G1-G2 核心页）

> 会话页可视稿见聊天中 `hermes_chat_mockup.html`；以下按页列结构/组件/状态。

**① 连接页（G1 已有 v0）**
- 结构：引导文案（两种接入方式）→ 地址/Token 输入 → [检测本机网关][连接/断开][进入会话] → 状态行
- G1.1：连接记录（记住上次成功的地址）、连接诊断（ping/延迟/版本）、
  本机模式引导卡（检测失败时给 Termux 命令复制按钮）

**② 会话列表页（G2）**
- 结构：搜索框 + 分组列表（今天/本周/更早；按 profile 标签过滤）+ 右上「新会话」
- 行：标题（session.title 事件自动命名）· 时间 · 未读/运行中指示点
- 交互：左滑归档/删除；点进会话页；运行中的会话行内显示 spinner

**③ 会话页 ★（G1 已有骨架）**
- 结构：AppHeader（返回+标题+状态 chip）→ 会话面板行（审批模式/工具集/会话 id，点开抽屉）
  → 消息流 → 输入条
- 消息流四型条目：系统行（虚线框 12px）、用户（primary 深色右对齐）、
  工具行（灰等宽 12px；G2 升级为可展开工具卡：参数/输出/diff）、助手（白卡 14px）
- 流式：message.delta 光标 + thinking.delta「思考中」（已接）
- 状态：连接 chip（绿点/红点）、busy 时发送按钮变「停止」、断线顶部变红 + 系统行
- G1.1：断线自动重连（replay epoch）、错误可重试、长文本/代码块样式
- G2：附件、图片、斜杠命令面板、语音按钮、审批卡（pending → 询问/允许/拒绝）

**④ 命令面板（G2）**：全局 ⌘K 等价——底部弹出浮层，搜会话/命令/文件/设置项，回车直达

**⑤ 文件/预览页（G2）**：左树右预览（手机为上下切换）；文件查看（文本/图片/pdf）、
  下载、diff 审阅（G3 并入 Git review）

**⑥ 任务页（G3）**：Cron 列表（启停/编辑）、Delegation 子任务卡、Kanban 看板

**⑦ 资源页（G3）**：Skills（列表/详情/Hub 搜索安装）、Memory（MEMORY/USER 编辑 + 搜索）、
  人格（SOUL.md）

**⑧ 设置页（G3）**：Provider/模型、config 分区、Secrets/Vault、Profiles、MCP/Plugins、
  通知、外观（主题/语言）、语音、关于

**⑨ 移动壳（G4）**：通知中心（审批/完成/定时三类必达）、悬浮窗（会话迷你窗）、
  Live2D 层（agent 状态→表情）、深链、生物锁

## 4. 移动端增量（Desktop 没有的）

1. **通知是第一公民**：审批请求/任务完成/定时触发必须推系统通知（Desktop 是"人在窗前"，手机不是）；
2. **弱网/离线**：断线队列、重连续传、"后台 agent 持续流"的移动端兑现（前台服务）；
3. **悬浮窗/画中PiP**：M-C4 对应物；
4. **Live2D 壳**（M-C）：agent 状态 = 表情（思考/空闲/报错）；
5. **运行时引导**：检测 Termux/内置 Ubuntu 状态，未就绪时给安装引导（对应官方 Termux 包现状：修复中，canary 可试）；
6. **系统集成**：分享进消息、快捷设置 tile、剪贴板、生物识别锁。

## 5. 分期路线

| 期 | 内容 | 验收 |
|---|---|---|
| **G0 协议侦察** | §1.1 清单；出《gateway 协议接口清单》 | 手写一条 WS 聊天能通 |
| **G1 聊天最小闭环** | 连接页（Remote + token）+ 会话页（流式对话 + 工具卡 + 输入条）+ 通知 | 手机连 PC gateway 聊天/看工具流 |
| **G2 对齐 Desktop** | 会话管理、diff/artifacts/预览、文件浏览器、审批流、语音 | Desktop 同款工作流在手机走通 |
| **G3 管理面** | 设置全家（Provider/config/Secrets/Skills/Memory/Cron） | 常用管理不回电脑 |
| **G4 移动特色 + 本地运行时** | 通知中心/悬浮窗/Live2D 壳 + Termux/内置 Ubuntu 接入（蓝图 M-A 安全层并行） | 断外网纯本地可用 |

> 依赖关系：G1 不依赖蓝图 M-A（先连远程 gateway）；G4 才与 M-A/DSHA 宿主方案交汇。
> 手柄控制（已有）与本线并行不冲突，同属 my_app 功能域。

## 6. 与既有文档的关系

| 文档 | 关系 |
|---|---|
| `MOBILE_HERMES_BLUEPRINT.md` | 本页是其"my_app 跨端壳"的 **UI 展开**；M-A/B/C/D 仍是运行时/记忆/形态层 |
| `ROADMAP.md` | 「Hermes 客户端」为新 epic，按 §5 分期入池 |
| `VISION.md` | 移动优先、桌面互补的新落点 |
| `docs/PITFALLS.md` | 协议/流式/通知相关新坑按既有格式追加 |

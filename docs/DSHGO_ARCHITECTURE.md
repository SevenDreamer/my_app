# dsh-go 架构深剖（2026-11-04，源码级）

> 合规：AGPL-3.0——本文只记架构/协议设计（学设计），零代码引用。

## 一、分层全景

```
┌─ Flutter UI 层（Riverpod，state/ 20+ 状态模块）
│    聊天/会话/命令/市场/桌宠(pets)/遥控(remote)/手机操控(phone)/论坛
│    └─ plugins/seams 插件槽位系统（见四）
├─ packages/dsh_client（纯 Dart，无 Flutter 依赖，可单测）
│    ├─ connection.dart   连接层（见二）
│    ├─ mux.dart          WS 多路复用（见三）
│    └─ 20 个 API 模块：agents/messages/files/goals/cordis/editors/
│       engine_settings/features/deliverables/dsbot/mux/models/…
└─ Kotlin 原生层（Flutter 插件式：一能力一 Plugin.kt）
     ├─ runtime/：RuntimeInstaller → DshProcess → DshService(前台服务) → RuntimePlugin
     ├─ 能力插件：files/icons/islands(灵动岛)/launch/diagnostics…
     └─ 通道：MethodChannel dsh/runtime + EventChannel dsh/runtime/events
runtime/ 运行时打包：boot/bridge/direct/lib/locks/media/patches/session-deletion
tooling/：build-apk.sh / apk_delta.py(增量包) / release_assets.py
```

## 二、连接协议（connection.dart 设计）

1. **登录**：`GET /?token=<launch token>`（dsh web 每次进程启动生成）→ 换
   **签名会话 Cookie**（绑 host:port authority，30 天有效，签名密钥在
   `$DSH_HOME/.credentials.yaml`——dsh web 重启不失效，**换 launch token 无感**）。
2. **持久化**：cookie 是 bearer 凭证 → secure storage 持久化，**401 才重登**。
3. **双通道**：HTTP REST（普通交换）+ **WebSocket upgrade**（流式）；
   全部带正确 Host 头、**永不发 Origin**（绕浏览器 CSRF 约束）。

## 三、多路复用协议（mux.dart：`/api/remote.mux` WS）

**一 socket 多逻辑流**，帧 = JSON 文本一帧一消息：

```
client→host  {"type":"open","streamId":"<uuid>","endpoint":"session/follow","payload":{…}}
             {"type":"item","streamId":…,"value":…}   上行
             {"type":"end"|"cancel","streamId":…}     半关/取消
host→client  {"type":"item"|"end"|"error","streamId":…,"error":{code,message,details}}
```

- 内部 `$events` 流：每连接代必开，首帧 `{type:"ready",clientId,host}`，
  之后 carry `emit`/`waterfall`/`cancel`。
- **Host 每 2s 心跳**；重连有 backoff + pending-request 记账。
- **断线期间的通知不重放**（明示语义，调用方自己补偿）。
- 物理链路抽象 `DshCarrier`：本地 = 该 WS；远程 = 加密隧道（remote/relay/ssh）。

## 四、插件槽位系统（plugins/seams：「声明式渲染隔离」的实现）

**核心思想**：插件不带可执行 UI 代码，只发 **ui.json 声明**；App 用自己的组件
在「槽位」里渲染声明。

- `slot_catalog.dart`：**槽位目录**（如 `settings.section`、列表、键值格）。
- `seat_models.dart`：`SlotOccupant`（slot + npm 包名 + cell + label + official 标记）。
- `seat_planner.dart`：**排座位**（多个插件在同槽位的布局规划）。
- `plugin_seat.dart` / `seat_state.dart`：座位状态（Riverpod）。
- 原生能力经 `native/`（native_files/native_surface/native_effects…）——
  插件经 Cordis 面板审批后才可调（批准运行在网页版）。

**安全收益**：插件代码不在 App 进程执行 = 零注入面；声明有限词汇 = 可审计。

## 五、运行时生命周期（Kotlin runtime/）

```
RuntimeInstaller（解包 runtime/out/<abi>/，进度经 EventChannel 推）
  → DshProcess（proot 起容器内 dsh web；lib*.so + useLegacyPackaging）
  → DshService（前台服务，防回收）
  → RuntimePlugin（MethodChannel：getStatus/install/start/stop/getLogs/reset）
RuntimeStatus：{abi, bundledVersion, installedVersion, phase(7 态), baseUrl, token, error}
日志协议：LogEntry{seq,line,stream}——seq 进程内递增不归零；快照+增量
  （getLogSnapshot 给 throughSeq，事件只接 seq>throughSeq）不重不漏。
```

**打包**：Gradle abi 风味（arm64/x64 各带各的资产+abiFilters）；
`targetSdk=28` 绕 Android 10+ exec 限制；tooling 拒收跨架构包。

## 六、对我们（my_app）的借鉴清单（只学设计）

| 设计 | 借鉴去处 |
|---|---|
| token→cookie 会话（401 重登）| DSH 对话线的 Web API 接入 |
| mux 流帧协议（open/item/end/cancel + 心跳 + 不重放语义）| 我们的流式通道（对话/诊断）|
| EventChannel seq 不漏行协议 | Sentry 诊断日志面增强 |
| **插件槽位系统**（声明式渲染隔离）| F3 插件市场 UI 的安全设计 |
| official-parity 逐项对齐表 | 功能完备性管理 |
| abi 风味分包 / apk_delta | 发包优化（当前 277MB 全量，可学减重）|
| 纯 Dart 客户端包（无 Flutter 依赖）| dsha_core 已同思想 ✓ |

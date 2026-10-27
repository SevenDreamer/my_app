# Hermes Gateway 协议接口清单（G0 侦察成果）

> 状态：v0.1（2026-10-27）｜来源：`github.com/NousResearch/hermes-agent` 实读（非文档转述）
> 用途：安卓客户端 `features/hermes/` 的地基——`packages/hermes_gateway/` 按本清单实现
> 权威位置：`tui_gateway/ws.py`（传输）、`tui_gateway/contracts/`（契约，pydantic 为真源）、
> `tui_gateway/rpc_dispatch.py` + `server.py`（方法实现）、`gateway/run_api.py`（鉴权/挂载）

## 0. 一句话

**`/api/ws` 上的换行分隔 JSON-RPC 2.0**（双向 NDJSON），accept 后服务端立刻推 `gateway.ready`；
与 Ink/stdio 完全同一套 dispatch——**CLI/TUI/Desktop/Webapp 都是这一个协议的不同客户端**。

## 1. 传输与生命周期

| 项 | 事实 | 出处 |
|---|---|---|
| 端点 | `@app.websocket("/api/ws")` | `tui_gateway/ws.py` 头注释 |
| 帧格式 | **newline-delimited JSON-RPC**（请求/响应/事件同帧形，事件为 `event` 通知帧） | 同上 |
| 握手 | accept 后服务端推 `gateway.ready` 事件 | 同上 |
| 保活 | 客户端 **每 15s ping**（同时是 gateway scale-to-zero 的存活标记，touch 文件 ≤5s/次） | `ws.py` |
| 断线重放 | `event_replay.replay_epoch`——按 epoch 重放错过的事件帧 | `tui_gateway/event_replay.py` |
| 旧客户端兼容 | `ws_legacy_fallback.dispatch_legacy`（legacy 帧形降级开关） | `ws_legacy_fallback.py` |
| 能力协商 | `client.capabilities`（客户端上报）/ `gateway.capabilities`（网关应答） | 方法面 |
| 会话语义 | "one conversation with one queue"：同会话多表面共享一条队列，后台 agent 持续流 | 文档+`session_*` 模块 |

## 2. 鉴权（三种形态，`gateway/run_api.py` 实证）

| 形态 | 机制 | 适用 |
|---|---|---|
| **本地 ticket** | owner-only **control socket** 铸造一次性 ticket（SPA session token 不给本地对端——"any loopback peer could read"，刻意 withhold） | 同机客户端 |
| **SPA session token** | `gateway.webapp_listener.browser_session_token(webapp.home)`，bearer 型 | 浏览器 webapp |
| **远程接入** | `auth_required` + `trusted_public_hosts` + 一次性签名链接（60s 内兑换）/ OAuth；`bound_host/bound_port` 边界态 | LAN/Tailscale/公网 gateway |

> 安卓客户端 G1 走「远程 gateway + token/OAuth」；本地形态（Termux/内置 Ubuntu）等 G4 再接。

## 3. 概念模型（从方法面反推）

- **Session**：创建/恢复/分支/压缩/归档/导出/控制（`session.*` ≈ 40 个方法）
- **Turn/Prompt**：`prompt.submit`（含附件/后台/追问）、`prompt.cancel`、`session.steer`（中途插话）
- **审批流**：`approval.pending/received/respond` + 事件 `approval.cancelled`
- **工具/命令**：`tools.list/configure/show`、`toolsets.list`、`command.dispatch/resolve/observe`、`commands.catalog`、`slash.exec`
- **显示通道**：`display.*`（start/stop/lease/thumbnail/observe）——Desktop workspace 的实时呈现面
- **组织**：projects（项目树/仓库发现）、profiles（多档案）、groups（多 agent 群组+对等复制）、kanban/subagent/delegation/spawn_tree

## 4. 事件面（65 个，全量）

流式核心（聊天 UI 必须处理）：

```
message.start → message.delta → message.interim? → message.complete
thinking.delta · reasoning.available · reasoning.delta
tool.start → tool.progress → tool.complete · tool.output_risk · tool.generating
agent.print · agent.terminal.output
```

交互与状态：

```
approval.cancelled · error · notice · status.update · gateway.ready · setup.ready
session.info · session.title · session.usage · session.reclaimed · session.resume_progress
session.control.update · sessions.changed · skills.changed · projects.changed
notification.show / notification.clear · tip.show · todo.updated · pane.reveal
```

长尾（各功能域的推送）：

```
billing.step_up.verification · bot_relay.outbox.pending · browser.progress · btw.complete
cron.changed · free_tier.challenge · moa.aggregating / moa.phase / moa.progress / moa.reference
pairing.changed · pet.changed / pet.generate.progress / pet.hatch.progress · platforms.changed
preview.close / preview.open / preview.restart.complete / preview.restart.progress
reaction · message.reaction · review.summary · skin.changed · terminal.close
voice.interrupted / voice.partial / voice.status / voice.transcript · wake.detected
```

> 契约注释明示：每个 `event` 帧 = `params.payload`，一类一模型（`contracts/events.py` 注册）；
> 字段以 Python emitter 为真源，`apps/shared/src/gateway-events.ts` 只是 TS 映射表。

## 5. 方法面（276 个，全量按组）

**对话/流程**（G1 核心）：`prompt.submit` `prompt.cancel` `prompt.background` `prompt.btw`
`prompt.receipt` `prompt.resolve_unknown` `approval.pending` `approval.received` `approval.respond`
`clarify.lock` `clarify.respond` `request.answer` `session.steer` `message.react` `clipboard.paste`
`paste.collapse` `input.detect_drop`

**会话**：`session.activate` `session.active_list` `session.archive` `session.automation`
`session.branch` `session.branch_stored` `session.branch_whole` `session.close` `session.compress`
`session.context_breakdown` `session.control` `session.control.read` `session.create`
`session.cwd.set` `session.delete` `session.detach` `session.events.since` `session.events.stats`
`session.export` `session.foreign.import` `session.foreign.list` `session.foreign.preview`
`session.history` `session.info` `session.interrupt` `session.list` `session.most_recent`
`session.mutate` `session.prune` `session.redirect` `session.resume` `session.save`
`session.set_hidden` `session.stats` `session.status` `session.title` `session.undo`
`session.usage` `session.workspace.move`

**工具/命令/补全**：`tools.list` `tools.configure` `tools.show` `toolsets.list`
`command.dispatch` `command.observe` `command.resolve` `commands.catalog` `slash.exec`
`complete.path` `complete.slash` `shell.exec` `cli.exec` `terminal.read` `terminal.resize`
`process.kill` `process.list` `process.stop` `window.read`

**文件/附件/预览/回滚**：`file.attach` `image.attach` `image.attach_bytes` `image.detach`
`image.generate` `pdf.attach` `preview.act` `preview.read` `preview.restart`
`rollback.diff` `rollback.list` `rollback.restore` `rollback.session_diff`

**显示/窗口**：`display.install` `display.install.sudo` `display.lease.acquire`
`display.lease.release` `display.observe` `display.start` `display.status` `display.stop`
`display.thumbnail` `pane.reveal`

**配置/模型/主题**：`config.get` `config.set` `config.show` `model.disconnect` `model.options`
`model.save_key` `theme.apply` `theme.pick` `reload.env` `reload.mcp`
`setup.runtime_check` `setup.status` `runtime.describe` `machine.facts`

**MCP/插件/技能**：`mcp.catalog` `mcp.servers.add` `mcp.servers.list`
`mcp.servers.oauth.callback` `mcp.servers.oauth.cancel` `mcp.servers.oauth.poll`
`mcp.servers.oauth.start` `mcp.servers.remove` `mcp.servers.set_api_key` `mcp.servers.status`
`mcp.servers.test` `plugins.catalog.lookup` `plugins.list` `plugins.manage`
`skills.manage` `skills.reload`

**凭据库**：`vault.add` `vault.code` `vault.list` `vault.lock` `vault.remove` `vault.save_login`
`vault.source.set` `vault.sources` `vault.unlock` `vault.unlock_prompt`

**项目/档案/群组**：`projects.add_folder` `projects.archive` `projects.create` `projects.delete`
`projects.discover_repos` `projects.for_cwd` `projects.get` `projects.list`
`projects.project_sessions` `projects.record_repos` `projects.remove_folder` `projects.set_active`
`projects.set_primary` `projects.tree` `projects.update` `project.facts`
`profiles.configure` `profiles.create` `profiles.describe` `profiles.get_asset`
`profiles.list` `profiles.set_asset`
`groups.approve` `groups.attachment.download` `groups.attachment.upload` `groups.capabilities`
`groups.create` `groups.demote` `groups.disband` `groups.discard` `groups.list` `groups.log`
`groups.peer.invite` `groups.peer.register` `groups.peer.revoke` `groups.promote` `groups.rename`
`groups.replica_state` `groups.replicate` `groups.retry` `groups.send` `groups.state` `groups.stop`

**任务/子代理**：`kanban.run` `delegation.pause` `delegation.status` `subagent.interrupt`
`subagent.list` `subagent.steer` `subagent.tail` `spawn_tree.list` `spawn_tree.load`
`spawn_tree.save` `worker.adopt` `worker.persist` `worker.register` `handoff.fail`
`handoff.request` `handoff.state` `cron.cancel` `cron.manage` `cron.recover` `cron.status`
`cron.submit`

**语音/唤醒**：`voice.record` `voice.toggle` `voice.tts` `wake.feed` `wake.pause` `wake.resume`
`wake.start` `wake.status` `wake.stop`

**计费/订阅/额度**：`billing.auto_reload` `billing.charge` `billing.charge_status`
`billing.keep_going_on_credits` `billing.state` `billing.step_up` `subscription.change`
`subscription.preview` `subscription.resume` `subscription.state` `subscription.upgrade`
`free_tier.ack_notice` `free_tier.challenge_result` `free_tier.claim_nudge` `free_tier.provision`
`free_tier.status` `usage.bars` `verification.status`

**机器人/联动**：`bot_relay.deliver` `bot_relay.outbox.drain` `bot_relay.reply`
`bot_relay.roster.sync` `connection.respond` `connectors.operation.status`
`connectors.operation.wake` `browser.manage`

**桌宠/学习/洞察**：`pet.cancel` `pet.cells` `pet.disable` `pet.export` `pet.gallery`
`pet.generate` `pet.generate.status` `pet.hatch` `pet.info` `pet.info.meta` `pet.remove`
`pet.rename` `pet.scale` `pet.select` `pet.thumb` `learning.delete` `learning.detail`
`learning.edit` `learning.frames` `insights.get` `llm.oneshot`

**遥测/杂项**：`agents.list` `client.capabilities` `gateway.capabilities` `diagnostics.share_nous`
`onboarding.set_run` `onboarding.skip` `onboarding.start` `onboarding.state`
`shared_metrics.desktop_daily` `shared_metrics.desktop_dislike` `shared_metrics.desktop_feature_use`
`shared_metrics.desktop_friction` `shared_metrics.desktop_onboarding` `shared_metrics.set`
`shared_metrics.slash_command` `shared_metrics.startup_latency` `shared_metrics.status`
`shared_metrics.update_run` `system.battery`

## 6. G1 最小集（安卓客户端第一批要接的）

| 维度 | 接口 |
|---|---|
| 连接 | WS `/api/ws` + 鉴权握手 → `gateway.ready`；`client.capabilities` 上报；15s ping |
| 聊天 | `prompt.submit`（`prompt.cancel` 停止）← `message.start/delta/interim/complete`、`thinking.delta` |
| 工具卡 | `tool.start/progress/complete`、`tool.output_risk`、`agent.print` |
| 审批 | `approval.pending/received` → `approval.respond`；`clarify.respond` |
| 会话 | `session.create/list/resume/history/info`、`sessions.changed`、`session.title` |
| 状态 | `status.update`、`error`、`notice`、`session.usage` |
| 断线 | replay epoch 重连 + `session.events.since` 补拉 |

> 附件/图片、语音、文件树、设置面按 G2/G3 排（方法已在 §5 全量在册）。

## 7. G0 剩余侦察项（字段级，随 G1 实现补全）

- [ ] 典型帧的 JSON 实例（请求/响应/事件三类各一条——以 contracts pydantic 模型为准逐字段抄）
- [ ] `message.delta` 的增量编码形态（纯文本片段 or patch）、`tool.*` 的 payload 字段
- [ ] replay epoch 的握手参数与补拉语义（`session.events.since` 的游标模型）
- [ ] 远程 token 的签发/轮换（sign-in link 兑换后的会话凭证形态）
- [ ] `client.capabilities` 的能力枚举（决定新旧 gateway 兼容策略）
- [ ] 对照实现：`apps/shared/src/gateway-events.ts` 与 web 前端连接器代码

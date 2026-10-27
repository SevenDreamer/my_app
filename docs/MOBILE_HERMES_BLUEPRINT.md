# 移动端 Hermes 蓝图 — 开源方案借鉴与落地路径

> 状态：v0.1 草案（2026-10-27）｜作者：wechat profile agent
> 前置：`VISION.md`（北极星）、`ROADMAP.md`（Phase 3 组网与控制）、`my-app-device-link` skill（已验证结论）
> 方法：**实际克隆并阅读源码**，非 README 摘录。五个仓的读码结论见 §2。

## 0. 一句话结论

**移动端 Hermes 的骨架（组网 + ADB 控制）已经存在且真机验证通过**，缺的不是「能力」，
是「**工程化安全层**」和「**人格/记忆层**」。

- 能力层：`my-app-device-link` Milestone ①② 已验证 —— `flutter_p2p_connection` 组网 +
  Termux adb server + Rust `adb_client` 触控注入/截屏，K40 + K80 双机全通。
- 缺口：这套通道目前是**裸 shell 全权限**，无重放保护、无命令白名单、无用户避让、
  无子进程隔离。敢不敢日常用，取决于这四层。

**可直接搬代码的只有 DSHA（MIT）**；Coopanion 是 AGPL，只能学设计不能搬代码。

---

## 1. 借鉴对象与许可判定

按 `oss-code-reuse-license-audit` skill 的顺序：**先查许可，再看代码**。

| 项目 | 许可 | 技术栈 | 能搬代码？ | 对本项目的价值 |
|---|---|---|---|---|
| **DSHA**<br>`DSH-APP/DSHA` | **MIT** ✅ | Java 1096 文件<br>+ Python 脚本 | ✅ **可直接搬** | ADB 桥、退出码契约、命令白名单、虚拟屏 |
| **Coopanion**<br>`Pal-AI-Lab/Coopanion` | **AGPL-3.0** ❌ | TS 570 文件<br>+ Electron | ❌ 只能学设计 | CUA 四层设计（权限/避让/坐标/隔离） |
| **Miru**<br>`kiyotakali/Miru` | **Apache-2.0** ✅ | Python 195 文件<br>+ Capacitor | ✅ 可搬（重写到 Dart/Rust） | 记忆架构（sleep agent + core memory + attention） |
| **Live2DPet**<br>`x380kkm/Live2DPet` | **MIT** ✅ | Electron/JS 5432 行 | ✅ 可搬 | 情绪累积、关键帧视觉记忆 |
| **pet**<br>`wangeguo/pet` | **Apache-2.0** ✅ | **Rust** 52 文件 | ✅ 可搬 | 同语言，IPC + tray + Bevy |

### 1.1 AGPL 为什么是硬墙

Coopanion 的 LICENSE 开头原文：

> Coopanion is licensed under the GNU Affero General Public License, version 3 or
> (at your option) any later version... **The permission covers every part of this
> repository, its packages included.**

整个仓库（含 `packages/` 所有扩展）都是 AGPL。`my_app` 无 LICENSE 文件 = 默认保留所有权利的闭源项目。合入 AGPL 代码的后果：

1. 整个 my_app 可能被认定为**衍生作品**，需公开全部源码
2. AGPL 第 13 条把触发条件扩展到**通过网络提供服务** —— 我们正在做 R2 分发 + Shorebird 热更，等于把闭源 APK 摊开在公网
3. Flutter + Rust 混合栈让「结合边界」更难划清，**风险更高而非更低**

**绕开的三条路**（本方案采用 1 + 2）：
1. 当**外部依赖**运行，通过 HTTP/WebSocket 调用，不合代码
2. 只学**设计思路**，用自己的技术栈重写 —— 思想不受许可保护，实现才受
3. 换许可宽松的同类项目

### 1.2 传递依赖审查（三个可搬仓）

对 DSHA / Live2DPet / Miru 全仓 grep `affero|AGPL`：**三个都是零命中**。
DSHA 与 Live2DPet 均有 `THIRD_PARTY_NOTICES.md`（**合入前必读**，确认 vendored 组件无 AGPL）。

> 注意：Live2DPet 的 `package.json` 里 `license: None`，但仓库根 LICENSE 是 MIT。
> 按审计规则这属于「许可不明 → 停下来问」。倾向以 LICENSE 文件为准，但**合入时必须保留版权声明**。

---

## 2. 五仓读码结论（实测，非 README）

### 2.1 DSHA —— 与本项目同一条路，且更成熟

**关键发现**：`AdbBridge.java` 的注释直说它跟我们的方案是同一条路：

> ADB 无线配对桥（**绕过 Shizuku**，通道直连设备 adbd）。把 assets 里的
> adb-pair.py / adb-shell.py / adb-setup.sh **注入 rootfs**，在容器内用
> **TLS1.3-PSK + SPAKE2** 完成「无线调试配对 → 直连 adbd」，拿到 `uid=2000(shell)`。

我们是 Termux 跑 adb server → `adb_client` 连 `127.0.0.1:5037`；DSHA 是注入 proot 容器。
**通道相同，只是宿主不同**（详见 `my-app-device-link` skill 的 001a 验证）。

#### 核心资产（可直接搬的四个文件）

| 文件 | 行数 | 作用 | 能否直接用于 my_app |
|---|---|---|---|
| `assets/adb-shell.py` | 515 | 执行链、三态退出码、重放保护、通道降级 | ✅ 纯 Python，Termux 可跑 |
| `assets/device-shell-policy.py` | 336 | 命令白名单、路径校验、符号链接逃逸防护 | ✅ 纯 Python，可直接用 |
| `assets/adb-pair.py` | 175 | SPAKE2 配对 | ✅ 纯 Python |
| `assets/adb-setup.sh` | 119 | 环境准备 | ⚠️ 需改（它的 rootfs 路径假设） |

#### 它解了我们的三个隐患

**① 三态退出码 + 发送后禁止重放**

```
124 = 连接失败/超时        → 命令没发出，可重试
125 = 已发送但执行结果未知  → 禁止自动重放
126 = 策略拦截             → 根本没执行
```

`adb-shell.py:230` 的 `run_on_endpoint()` 里，三态边界写得极清楚：

```python
# 连接阶段的任何异常 → ConnectFail（124，可重试）
except Exception as e:
    raise ConnectFail('%s:%d %s: %s' % (host, port, type(e).__name__, str(e)[:200])) from e

marker = '__DSHA_EXIT_' + uuid.uuid4().hex + '__='
# 从这里开始即使异常也禁止换地址重放，包括不兼容库抛出的 TypeError。
try:
    raw = dev.shell(frame_command(command, marker), ...)
    return parse_shell_result(raw, marker)
except Exception as e:
    raise ExecutionUnknown('%s:%d 返回中断（%s）；命令可能已执行，请先检查设备，未自动重试'
                           % (host, port, type(e).__name__)) from e
```

用 UUID marker 帧包住命令，从 marker 定义那一行起，任何异常都归 125。
**我们现在的方案没这个区分** —— `input tap` 超时后盲目重放会点两次。

**② 命令白名单在原生侧判定，不信任远端文本**

`device-shell-policy.py:13`：
```python
def argv_command(argv):
    name = argv[0]
    if not re.fullmatch(r'[a-zA-Z0-9_.-]+', name):
        raise Blocked('执行计划包含未知入口')
    # 强制 /system/bin/ 前缀 + shlex.quote 转义
    return ' '.join(shlex.quote(v) for v in ['/system/bin/' + name] + argv[1:])
```

`write_allowed()` 的路径校验更严：拒绝 `..`、拒绝 `\0 * ? [ ] \r \n`、规范化后必须匹配存储白名单，
且**逐级核对祖先目录的实际路径**（防符号链接逃逸）：
```python
if not write_allowed(canonical, we):
    raise Blocked('实际路径属于受保护目录：' + canonical)
```

**我们的通道目前是全权限 shell**，agent 能执行任意命令。

**③ 执行通道三层降级 + token 鉴权**

`adb-shell.py:423` 的 `request_native_execution()`：
```
原生层先选 root/Shizuku；仅收到明确的 ADB 计划才连接，不重放未知结果。
请求 http://127.0.0.1:3090/device/execute?cmd=...&su=0&adb=0
     Header: X-Token: <从 /root/.dsh/.bridge_token 读>
返回 state: 'completed' | 'adb'
     若 'adb' → 返回明确 plan（kind ∈ READ/FILE/STOP, version=1）
```
**localhost HTTP + token + 明确 plan 契约**。我们现在是进程内 FFI 直调，没有这层边界。

#### 我们完全没想到的一块：8379 行虚拟屏

`app/vscreen/` 26 个文件，补上了 Coopanion「坐标系换算」问题的解法：

- `VirtualScreenAnchorProof.java`（406）+ `VirtualScreenPeerProof.java` —— **锚点证明 / 对端证明**，
  用证据链确认点击确实作用在预期控件上
- `VirtualScreenObservedControl.java`（472）+ `ObservedPixels.java` —— 观察到的控件/像素，验证操作真生效
- `VirtualScreenAccessibility.java`（479）—— 无障碍服务读控件树
- `VirtualScreenPreviewInputGate.java` —— 预览输入闸门，防误触

**手机旋转/分屏后坐标失效**，DSHA 用「观察证据 + 锚点证明」解决 —— 这正是我们 ROADMAP 里没有的新能力。

#### 保守的 proot/proroot 策略（值得学）

`ConfigStore.java:310`：**默认稳定的 proot；只由用户显式选择启用 proroot。**
`ColdInstallPlan.java:78`：`if (preferProroot && prorootAvailable && isolated) modes.add(PROROOT)`
—— proroot 要三个条件齐备才启用，不齐就退回 proot。

### 2.2 Coopanion —— 设计可学，代码不可搬

**真实架构**（`packages/cortico-world-desktop-pet/` 19851 行）：

```
src/world.ts          2153 行  桌宠心脏
src/cua/cua.ts         657 行  computer use
src/cua/engine/       darwin.ts / win32.ts / linux.ts
src/server.ts         476 行
src/packs.ts          438 行  形象包系统
src/runtime/store.ts  292 行
core/seed/persona/*.md         人格种子（5 角色 × 12 语言）
```

**`cua/engine/darwin.ts` 是真的 macOS 实现**，用 koffi 直接调 CoreGraphics：
```js
const cg = koffi.load('.../CoreGraphics.framework/CoreGraphics');
CGPreflightScreenCaptureAccess()   // 屏幕录制权限预检
CGRequestScreenCaptureAccess()     // 请求权限
CGPreflightPostEventAccess()       // 辅助功能权限预检
CGEventCreate()                    // 注入鼠标键盘事件
CGWindowListCopyWindowInfo()       // 窗口列表
```
截屏走系统 `screencap`，输入走 CoreGraphics 事件，AppleScript 负责置前 app。
**权限没给时抛异常并说明去哪开** —— 这正是 macOS 安装坑的代码依据。

#### 它暴露给 agent 的能力（与我们 ADB 通道逐个对应）

基础动作 7 个：`pet_say` · `pet_ask` · `pet_move_to`（可中断）· `pet_act` · `pet_set` · `pet_quiet` · `pet_cua_open_settings`

Computer Use 11 个（`cuaOn` 时追加）：

| Coopanion（桌面） | 我们 K80 ADB 方案 | 状态 |
|---|---|---|
| `pet_cua_screenshot` | `screencap` | ✅ 已验证 |
| `pet_cua_click` / `move` / `drag` | `input tap` / `swipe` | ✅ 已验证 |
| `pet_cua_type` | `input text` | ✅ 已验证 |
| `pet_cua_key` | `input keyevent` | ⬜ 未验证 |
| `pet_cua_windows` | `uiautomator dump` | ✅ 已验证 |
| `pet_cua_focus` | `am start` / `input keyevent` | ⬜ |
| `pet_cua_zoom` | 重截屏裁剪 | ⬜ |
| `pet_cua_wait` | 轮询 + sleep | ⬜ |

#### 我们缺的两层（AGPL 只禁代码，禁不了设计）

**① 用户避让（yield）—— 我们完全没有的机制**

`cua.ts` 顶部说明：
> Input tools first wait for the user to leave mouse and keyboard alone (`userIdleMs`),
> up to `maxYieldWaitMs`, and fail without acting if the user keeps going.

每次输入都带 `yield: this.yieldCfg`。**手机上这叫「抢手指」** ——
我们的 ADB 触控注入目前是硬注入，会和用户手指打架。**这是日常可用性的刚需。**

**② 引擎子进程隔离**

> All operating-system calls run in an engine child process (`engine-child.ts`).
> A crash or an unanswered request past its deadline fails that engine's calls;
> a timed-out engine is killed and the next call starts a fresh one.
> `ENGINE_TIMEOUT_MS = 30_000`

我们现在跑在 app 主进程里，**一次 ADB 挂掉会拖累整个 app**。

**③ 权限分级（`PERMISSION_LEVELS`）**

每轮最多问一次 / 首次读屏前 / 首次输入前 / `grantMinutes` 内不再问 / 永不问。
拒绝在本轮内持续有效。`PERMISSION_TIMEOUT_MS = 60_000`。
—— **60 秒超时与用户偏好里的审批约定完全一致**。

**④ 坐标系换算**

> 截屏缩放到 `maxWidth×maxHeight`；工具坐标是最新截屏的像素，映射回物理像素。
> 若截屏后显示器排布变了，引擎拒绝该输入。

**在手机上对应旋转/分屏/折叠** —— 我们目前假设固定坐标系，屏幕一转就废。

### 2.3 Miru —— 记忆架构的成品参考

**真实结构**（不是 Tauri 桌宠）：
```
Miru/
├── 195 个 Python 文件   ← 大脑（Flask 后端 + 记忆系统）
├── miru-mobile/         ← 移动端！Capacitor + Android
│   ├── capacitor.config.ts  appId: com.miru.companion
│   ├── android/  AndroidManifest.xml
│   └── www/index.html       ← WebView 壳，加载远程 Flask
├── src-tauri/           ← 桌面壳
└── soul.md              ← 95 行人格定义
```

**它的移动端方案就是「手机当显示器，电脑当大脑」** —— Capacitor WebView 连 Flask 后端
（`allowNavigation: ['*']` + `cleartext: true` 走 LAN）。`sensor.py` 明写：
> For the Mac (local backend), this POSTs to localhost. **For remote devices, it POSTs to
> the backend's LAN/public IP.**

**这跟我们 K80↔Mac 的 webhook 双工架构是同一个思路。**

#### 四个最值钱的模块

**① `attention_engine.py`（2158 行）—— 持续内隐在场**

取代 CareEngine，是「让 Miru 一直知道用户在干嘛」的运行时：
```
1. 接收信号（截图/聊天/活动/承诺）
2. 合并成少量 LLM tick（不是每条消息都触发）
3. 更新用户情感 + Miru 自身情绪
4. 写 attention_log.json / attention_state.json，含 speak_intent
5. 队列化 speak_intent 主动投递
6. 让 proactive 主 agent 把 intent 变成一句自然的话
```
> 核心产品思路：Miru 持续观察、理解、关心，像 soul.md 定义的角色那样。
> **Attention LLM 决定「说还是保持安静」；主 agent 只负责写最终措辞。**

**这正是大黄鱼「选择性发言是人格的一部分」的工程实现。**

**② `sleep_agent.py`（505 行）—— 借 Letta 的 Sleep-time Compute**

```
enqueue(role, text) → debounce 3 分钟（或 12 条消息上限）→ 快照批次
  → Slot Writer（每批）→ 匹配槽位 → Pass 4 AppendEditor 追加
  → persona_writer_state.record_batch 累积
  → 每 4 批 → Persona Writer → human_update / persona_update
```
> 聊天 agent 专注对话质量（实时，chat_history 已在 prompt 里，不依赖 sleep agent 新鲜度）；
> sleep agent 专注记忆质量，纯后台跑，**故意 debounce 以看到完整对话上下文而非碎片**。

**③ `core_memory.py`（350 行）—— 借 Letta/MemGPT 两级记忆**

```python
DEFAULT_BLOCK_LIMIT = 5000   # ~1500 汉字 / ~1.5K tokens
SOFT_RATIO = 0.80            # 到 80% 满就主动压缩
TARGET_RATIO = 0.60          # 压到 60% 满
```
Core Memory（小、常驻 system prompt、agent 可编辑）+ Archival Memory（大、可搜索、agent 可写）。
**压缩用便宜 LLM。这个 token 预算设计很实用。**

**④ `miru_emotion.py`（536 行）—— Miru 自己的情绪**

> 不同于 emotion_log（追踪**用户**情绪），这管 **Miru 自己的感受**。LLM 看到完整时刻快照
> （今天带时间戳的聊天、距最后一条消息的秒数、用户情感弧线、persona/human 核心记忆块、
> 当前 Miru 状态），所以它能**感受到「我几个小时没被回复了」**，而不用硬编码离线预设。

### 2.4 Live2DPet —— 情绪累积与视觉记忆

MIT，Electron/JS 5432 行。`src/core/enhance/` 那套记忆系统：
- `vlm-extractor.js`（487）—— 视觉语言模型抽关键帧
- `memory-tracker.js`（105）—— 窗口焦点活动记录
- `knowledge-acquisition.js`（283）+ `knowledge-store.js`（93）
- `context-pool.js`（177）+ `enhancement-orchestrator.js`（104）

`emotion-system.js`（397）：**情绪值随时间累积，到阈值才用 AI 选情绪**，然后回调输出情绪名。
—— 解耦设计，表达渲染交给 `desktop-pet-system` → `ModelAdapter`。

### 2.5 pet —— 同语言的 Rust 桌宠

Apache-2.0，**Rust 52 文件**，`crates/` workspace：`app` / `common` / `manager` /
`settings` / `theater` / `tray`。用 Bevy 0.19 + iced 0.14 + winit 0.30。

**跟我们 `rust/` workspace 同语言**，它的 `crates/app/src/ipc/`（router + server）
和 `crates/common/`（config / paths / storage / autostart）可以直接参考。

---

## 3. 方案总览

**核心判断**：Coopanion 证明了 CUA 的本质是「**权限门 + 避让 + 坐标映射 + 引擎隔离**」
这四层，**跟底层用 CoreGraphics 还是 ADB 无关**。我们的 ADB 通道是后端，缺的是这四层。

**所以方案不是「把 Coopanion 搬过来」（AGPL 不行），而是：**

| 层 | 借谁 | 怎么落 |
|---|---|---|
| **CUA 四层设计** | Coopanion `cua.ts` 657 行 | **读码学思路，Rust 重写**（AGPL 只禁代码复用，不禁设计） |
| **后端执行 + 安全层** | DSHA 四个 Python 文件 | **MIT，可直接搬**（Termux 直接跑） |
| **记忆/人格** | Miru `core_memory.py` + `attention_engine.py` | Apache-2.0，**可直接搬**（Dart/Rust 重写或 Mac 端跑 Python） |
| **Live2D 渲染** | 我们已有 | my_app 现成（Cubism Core 6 补丁已落地） |
| **形象包系统** | Coopanion `packs.ts` 438 行 | 学它 —— 我们 ROADMAP 里「Live2D 模型导入 zip」正是这个 |

### 3.1 目标架构

```
┌─────────────────────────────────────────────────────┐
│  K80（Android，跑 Termux + Hermes agent）             │
│  ├─ 传感器：screencap / input tap / uiautomator dump │
│  ├─ 安全层（新增，借 DSHA）                            │
│  │   ├─ 三态退出码 + 发送后禁止重放                    │
│  │   ├─ 命令白名单（原生侧判定）                       │
│  │   └─ 用户避让 + 权限分级（学 Coopanion）            │
│  └─ 引擎子进程隔离（学 Coopanion）                     │
└──────────────────┬──────────────────────────────────┘
                   │ flutter_p2p_connection（已验证）
                   │ ADB tcpip 5555（已验证）
┌──────────────────▼──────────────────────────────────┐
│  Mac（注意力引擎 + 记忆持久化 + 压缩）                  │
│  ├─ attention_engine（借 Miru）                       │
│  ├─ sleep_agent 记忆整理（借 Miru）                    │
│  └─ core_memory 两级记忆（借 Miru）                    │
└──────────────────┬──────────────────────────────────┘
                   │ webhook 双工（已跑通）
┌──────────────────▼──────────────────────────────────┐
│  my_app（跨端壳：Flutter Live2D + 悬浮窗）             │
│  ├─ Live2D 渲染（已有，Cubism Core 6）                │
│  └─ 情绪引擎（借 Live2DPet + Miru 思路，Dart 重写）     │
└─────────────────────────────────────────────────────┘
```

**这比 Miru 的 WebView 方案更原生**，且我们已有的设备验证（adb 触控注入、screencap、
跨进程读设备列表）全部复用。

---

## 4. 分阶段实施

### M-A：ADB 通道加固（最高优先级 — 从「能用」到「敢日常用」）

**为什么最急**：我们 Milestone ② 已验证技术可行，但当前是裸 shell，日常用会有真实风险。

| 项 | 借自 | 行数 | 验收 |
|---|---|---|---|
| A1. 三态退出码契约 | DSHA `adb-shell.py` | ~120 | `input tap` 超时后不重放，返回 125 |
| A2. 命令白名单 | DSHA `device-shell-policy.py` | ~336 | 非白名单命令返回 126；`rm -rf /` 被拦 |
| A3. 符号链接逃逸防护 | 同上 `write_allowed()` | ~40 | symlink 指向受保护目录时被拒 |
| A4. 用户避让（yield） | Coopanion 设计，Rust 重写 | ~150 | 手指触摸屏幕时注入暂停，最多等 N 秒 |
| A5. 权限分级 + 60s 超时 | Coopanion `PERMISSION_LEVELS` | ~80 | 首次注入前询问；60s 无响应即失败 |
| A6. 引擎子进程隔离 | Coopanion `engine-child` 思路 | ~100 | ADB 挂掉不拖累 app，自动重启引擎 |

**落地路径**：A1/A2/A3 直接搬 DSHA 的 Python（MIT，Termux 有 Python，零改动可跑）；
A4/A5/A6 用 Rust 重写（Coopanion 的 TS 思路 + 我们已有的 `adb_client` Rust 栈）。

**验收**：日常使用 K80 注入触控时，用户手指触摸屏幕 → 注入暂停；超时 → 返回 125 不重放。

### M-B：记忆与人格层（借 Miru，Apache-2.0 可直接搬）

| 项 | 借自 | 落到哪 | 验收 |
|---|---|---|---|
| B1. 两级记忆（core + archival） | Miru `core_memory.py` | 大黄鱼 SOUL.md 升级 | 人格块可编辑，agent 自己改自己 |
| B2. token 预算 + 自动压缩 | 同上（5000/80%/60%） | 同上 | 人格块超 80% 自动压到 60% |
| B3. sleep agent 记忆整理 | Miru `sleep_agent.py` | Mac 端后台 | debounce 3 分钟后批量整理 |
| B4. attention engine | Miru `attention_engine.py` | Mac 端 | 信号合并成 tick，LLM 决定说/不说 |

**为什么先做 B 而不是 C**：B 是**纯配置层，不动 my_app 代码**，当天能看到效果，
验证「可编辑人格记忆块」的价值后再决定要不要投入更多。

### M-C：形态与视觉层（借 Coopanion 设计 + Live2DPet 代码）

| 项 | 借自 | 落到哪 | 验收 |
|---|---|---|---|
| C1. 形象包系统 | Coopanion `packs.ts`（学设计） | my_app「Live2D 模型导入 zip」 | ROADMAP 未排期想法池里的那条 |
| C2. 情绪累积 + 阈值触发 | Live2DPet `emotion-system.js`（MIT 可搬） | Dart 重写 | 情绪值累积到 100 才用 AI 选表情 |
| C3. 关键帧视觉记忆 | Live2DPet `enhance/` | Mac 端 | 截屏 → VLM 选关键帧 → 存长期记忆 |
| C4. Android 悬浮窗 | —（Coopanion 是桌面置顶窗） | my_app 新页面 | `SYSTEM_ALERT_WINDOW` 权限 |

### M-D：远期 — 虚拟屏（借 DSHA 8379 行设计）

ROADMAP 里没有的新能力。DSHA 用「锚点证明 + 观察控件/像素」解决坐标失效问题。
**依赖 M-A 完成**（虚拟屏启动需要 ticket 门禁 + 一次性发送保护）。

---

## 5. 里程碑与验收标准

沿用 `my-app-device-link` skill 的里程碑编号，本方案是其**补充而非替代**：

| 里程碑 | 状态 | 本方案新增 |
|---|---|---|
| ① 连接最小闭环 | ✅ 已发版 | — |
| ② ADB 控制通道 | 🔶 技术已验证 | **M-A 安全层把它从「能用」变「敢日常用」** |
| ③ 局域网文件传输 | ⬜ | — |
| ④ 桌面控制端 + 指令面板 | ⬜ | M-A 的权限分级是它的前置 |
| **⑤ 安全层加固**（新增） | ⬜ | **M-A 六项** |
| **⑥ 记忆人格层**（新增） | ⬜ | **M-B 四项** |

---

## 6. 风险与合规

### 6.1 许可合规（硬约束）

- **AGPL 绝不碰代码**：Coopanion 只学设计思路，用 Rust/Dart 重写。这是法律边界不是偏好。
- **MIT / Apache-2.0 搬代码时保留版权声明**：DSHA / Live2DPet / Miru 都要在
  `THIRD_PARTY_NOTICES.md` 里登记来源。
- **合入前必读 DSHA 的 `THIRD_PARTY_NOTICES.md`**：确认无 vendored AGPL 组件。
- **Live2DPet 的 `package.json` 无 license 字段**：以仓库根 LICENSE（MIT）为准，
  但合入时保留版权声明，并在文档里标注这个不一致。

### 6.2 技术风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| DSHA 的 Python 脚本假设 rootfs 路径 | 直接搬可能跑不起来 | Termux 路径不同，需改 `KEYDIR` 等常量；先在 K80 单机验证 |
| 用户避让需要读触摸事件 | Android 权限限制 | 学 Coopanion 的 yield 设计，但 Android 侧用 `AccessibilityService` 或轮询 |
| 引擎子进程隔离在 Rust 里更复杂 | M-A6 可能超预期 | 参考 `pet` 的 `crates/app/src/ipc/` 进程模型 |
| 虚拟屏依赖无障碍服务 | M-D 可能受厂商限制 | HyperOS 实测无障碍可用，但需真机验证 |
| 记忆层跨端（K80 ↔ Mac） | 数据一致性 | Miru 用 webhook POST，我们已有双工架构 |

### 6.3 主权与协作约束

- **my_app 仓库主权归专属 myapp agent**，本方案文档是跨 agent 协作产物，
  代码实现应由 myapp agent 主导，其他 agent 旁观协作。
- 涉及外部库时 **Rust 与 Dart/Flutter 两侧都查**再下结论（用户明确要求）。
- 沟通流程：先给「现状 → 方案取舍表 → 推荐」，用户确认后再动手。

---

## 7. 参考资料

### 7.1 已克隆读码的仓库（本机路径）

```
/private/tmp/probe/DSHA/                    63M  MIT
/private/tmp/probe/Coopanion/               56M  AGPL-3.0（只读不搬）
/private/tmp/probe/Cortico/                 18M  MIT（Coopanion 的框架本体）
/private/tmp/probe/Miru/                    63M  Apache-2.0
/private/tmp/probe/Live2DPet/              8.6M  MIT
/private/tmp/probe/pet-rust/               1.8M  Apache-2.0
```

> ⚠️ `/private/tmp` 会被系统清理。若需长期保留，请在验证价值后移到持久位置。

### 7.2 关键文件速查

**DSHA（可直接搬）**
- `app/src/main/assets/adb-shell.py`（515）—— 三态退出码、重放保护、通道降级
- `app/src/main/assets/device-shell-policy.py`（336）—— 命令白名单、路径校验
- `app/src/main/assets/adb-pair.py`（175）—— SPAKE2 配对
- `app/src/main/java/com/deepseekharness/app/bridge/AdbBridge.java`（720）—— 桥接入口
- `app/src/main/java/com/deepseekharness/app/vscreen/`（8379，26 文件）—— 虚拟屏

**Coopanion（只学设计）**
- `packages/cortico-world-desktop-pet/src/cua/cua.ts`（657）—— CUA 四层
- `packages/cortico-world-desktop-pet/src/cua/engine/darwin.ts`（344）—— macOS 实现
- `packages/cortico-world-desktop-pet/src/world.ts`（2153）—— 桌宠心脏 + tools()

**Miru（可搬，重写到 Dart/Rust）**
- `attention_engine.py`（2158）—— 持续内隐在场
- `memory_router.py`（1618）—— 槽位路由
- `sleep_agent.py`（505）—— 后台记忆整理
- `miru_emotion.py`（536）—— 自身情绪
- `core_memory.py`（350）—— 两级记忆 + token 预算
- `soul.md`（95）—— 人格定义

**Live2DPet（MIT 可搬）**
- `src/core/emotion-system.js`（397）—— 情绪累积
- `src/core/enhance/vlm-extractor.js`（487）—— 关键帧视觉记忆

**pet（Apache-2.0，同语言）**
- `crates/app/src/ipc/`（router + server）—— IPC 模型
- `crates/common/`（config / paths / storage）—— 通用层

### 7.3 相关技能

- `oss-code-reuse-license-audit` —— 本方案 §1 的许可审计方法
- `my-app-device-link` —— Milestone ①② 的已验证结论（勿重复调研）
- `coopanion-desktop-pet` —— Coopanion 生态全景
- `dsha-android-dsh-launcher` —— DSHA 仓库基本盘

---

## 8. 附录：本方案与现有文档的关系

| 文档 | 关系 |
|---|---|
| `VISION.md` | 本方案是其「E. 设备控制（远期）」的展开 |
| `ROADMAP.md` | M-A/M-B/M-C 对应 Phase 3 的补充；M-D 是未排期想法池的新增 |
| `RUST_PET.md` | 本方案的 M-C4（Android 悬浮窗）是它的移动端对应物 |
| `docs/PITFALLS.md` | 实施本方案时新踩的坑按既有格式追加 |
| `my-app-device-link` skill | 本方案是其 Milestone ② 的**安全层补充**，不替代已验证结论 |

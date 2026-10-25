# 001: adb-termux-bridge —— 控制层命门验证

## 问题（Given/When/Then）

控制层走 ADB 无线调试通道（手机 A 控手机 B）。`adb_client` crate 的
`pair()` 是**代理给本地 adb server**（`host:pair:{code}:{addr}`），
app 进程内没有 adb server → 配对这步过不去。

**假设**：两台手机都装 Termux，手机 A 的 Termux 跑 `android-tools` 的
adb server（127.0.0.1:5037）→ app 内的 `adb_client`（ADBServer 模式）
连它 → pair / connect / shell / input 全链路打通。

| # | 验证（Given/When/Then） | 在哪跑 | 状态 |
|---|---|---|---|
| 001a | Given 两台手机 + Termux，When A 的 adb pair→connect→`input tap`，Then B 产生触控反馈 | 两台真机（纯命令行） | ⏳ |
| 001b | Given 本地 adb server，When `adb_client` crate 走 ADBServer 模式，Then 与 adb CLI 等价（pair/connect/shell） | Mac（rust_probe） | ⏳ |
| 001c | Given app 内 adb_client，When 连 Termux 的 127.0.0.1:5037，Then 跨进程 localhost 可达 | 真机 app（并入 004 FFI 集成） | ⏳ |

## 实测进展（2026-10-25，K40 单机全部完成）

### 001b ✅ VALIDATED（crate 与 CLI 等价性成立）

USB（8648305e）+ 无线（192.168.31.54:43033）双链路实测：

| 项目 | CLI | crate | 结论 |
|---|---|---|---|
| `getprop ro.product.model` | M2012K11C | M2012K11C | ✅ 逐字一致 |
| `id`（含 SELinux context） | uid=2000(shell)… | 同 | ✅ 逐字一致 |
| `input tap/swipe` 触控注入 | 生效 | 生效（截屏 MD5 前后不同佐证） | ✅ |
| `screencap` 截屏 | — | /sdcard 落盘成功 | ✅ |
| `connect_device` | `adb connect` 通 | 通（"already connected" 是 crate 响应串校验严格，非故障） | ✅ |
| `devices()` 列表 | `adb devices` | 同（USB+无线同时列出） | ✅ |

- 小米 K40（M2012K11C，Android 12 / API 31）：**input 注入未被拦**（USB调试安全设置应已开）
- 无线调试 connect 端口：`192.168.31.54:43033`；Mac 已是已配对设备（qiuzhixiong@seven.local），
  `adb connect` 直通——**001a 的 pair() 流程还没真正跑过**（无新配对码可验），
  待第二台手机到货用 Termux 端 `termux_probe.sh` 补上（那才是真命门验证）。
- `settings put global adb_wifi_enabled 1` 无效（Android 12 起系统服务专管），开无线调试需 UI 操作；
  但 **input 注入可以驱动任意 UI**——uiautomator dump 定位 + input tap 点击，已实测可行。

### 环境发现（影响后续所有 Rust 工作）

- **Mac 宿主链接器坏了**：CLT 的 ld-1267 读不懂自带 SDK 27.0 的新 tbd 格式
  （`arm64e.x1-macos` 未知架构），裸 `cc /tmp/t.c` 都链接失败。绕法：
  ```bash
  XT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
  XSDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
  SDKROOT="$XSDK" CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER="$XT/clang" \
    RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$XSDK" cargo build
  ```
  （彻底修：`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`）
  ⚠️ rust/pet 桌面构建同样会踩这个雷
- **rustup stable = 1.94.0**（被 PATH 里 Homebrew rust 1.85 遮住；`rustup run stable` 才是新版）
- **rustup 已装 Android 交叉编译全套目标**（aarch64-linux-android 等）——004 FFI 工具链现成
- `adb_client` 2.1.15 的 `shell_command` 签名是 `&[&str]`；`image` 是硬依赖（关 feature 甩不掉）

- Termux 官方仓库 `android-tools` 37.0.0p1-3（aarch64，2026-10-21）✅ 包名验证过
- `adb_client` 2.1.15 API：`ADBServer::new(SocketAddrV4)` 可连任意地址；
  `pair(code)` / `connect_device(addr)` / `get_device_by_name(serial)` 齐全 ✅
- `ADBTcpDevice`（直连设备）带 TLS 升级握手（STLS）✅ —— 连接层无忧
- 唯一缺口是 pair 代理问题，由 Termux adb server 填平

## 001a ✅ VALIDATED（2026-10-26 凌晨，K80 Termux → K40 全链路打通）

**方案最终形态（用户提议的 `adb tcpip 5555`，比 SPAKE2 配对码简单得多）**：

1. Mac 对 K40 发 `adb tcpip 5555`（一次性引导，重启失效）→ K40 的 adbd 开 5555
2. K80 Termux：`adb connect 192.168.31.54:5555` → 首次弹 **RSA 授权框**（`一律允许`勾选）
3. 授权框在 K40 上（用注入点掉：uiautomator 读坐标 + `input tap`）→ K80 重连即 `connected`
4. **验证**：`adb -s 99eda5d5 forward tcp:5038 tcp:5037` 后 `adb -H 127.0.0.1 -P 5038 devices`
   显示 `192.168.31.54:5555 device`（K40 已连已授权）→ 触控注入 swipe 后截屏 MD5 前后不同 ✅

| 验证项 | 结果 |
|---|---|
| K80 Termux adb 37.0.0p1 可用 | ✅（protobuf 全量 upgrade 修好 CANNOT LINK）|
| K80 adb server → K40 连接+授权 | ✅（RSA 弹窗流程跑通）|
| 通过链路触控注入 | ✅（MD5 佐证）|
| **001c 预演**：`adb forward tcp:5038 tcp:5037` 跨进程连 Termux 的 adb server | ✅ 端口转发直读设备列表成功 |

**对产品设计的关键输入**：
- `adb tcpip 5555`（经典无线）：无配对码，仅首次 RSA 授权弹窗；但**重启失效需重发引导命令**
  （引导来源：USB/root/已有 adb 会话——产品里可由被控端 app 用同法自启，或 Termux root 提权）
- 无线调试 SPAKE2 配对码（Android 11+）：零引导、重启后配对关系保留；配对码 30 秒过期
- **两条都支持**：首次配对用 tcpip（简单），长期关系存 RSA key（`一律允许`持久化）
- app 侧连 Termux adb server 的路径 = `127.0.0.1:5037`（001c 已预演成功）

**坑（都已踩过）**：
- Termux `android-tools` 37 有 protobuf 依赖 bug（CANNOT LINK），`pkg upgrade` 全量后修复
- K80 Android 16：RUN_COMMAND 广播被 RunCommandService 权限拦死（pm grant 也无效），**UI 注入是唯一可靠远程执行路径**
- `input text` 的 `%s` 空格转义在含 `>` 重定向的命令上会失效——输出用 `adb forward` 纯文本通道读
- 授权弹窗只出现在被控端（K40），视觉读图容易混淆两台机的截图——用 uiautomator dump 纯文本确认

---

（历史步骤存档）001a 操作步骤（两台手机）：

手机 B（被控端）：
1. 设置 → 开发者选项 → **无线调试** 开
2. （小米额外）开发者选项 → **USB 调试（安全设置）** 开（否则 `input` 注入被拦）
3. 点「使用配对码配对设备」→ 记下 **配对地址 `IP:端口` + 6 位码**（弹窗里的）
4. 关掉弹窗后记无线调试主页的 **连接地址 `IP:端口`**（⚠️ 与配对端口不同）

手机 A（控制端，Termux 里）：

```bash
bash termux_probe.sh <配对IP:端口> <6位码> <连接IP:端口>
```

预期：手机 B 出现点击反馈 + 截图落盘 → 001a 通过。

## 已知坑

- **配对端口 ≠ 连接端口**：弹窗端口只管配对，`adb connect` 要用主页端口
- 配对码 6 位数字，过期快（约 30 秒），先在 B 上打开弹窗再敲命令
- 小米：不开「USB 调试（安全设置）」时 `input tap` 静默失败
- 无线调试重启手机后要重新开（但配对关系保留，免重新配对）
- `adb start-server` 首次会拉起 server；Termux 杀后台后要重拉

## 001b：rust_probe

```bash
cd rust_probe && cargo run -- <serial> shell input tap 500 1000
```

连 Mac 本地 adb server（5037），对已配对设备执行命令，
与 adb CLI 输出比对一致 → crate 等价性成立。

## Verdict: PENDING

### What worked
- (待 001a/001b 跑完填写)

### What didn't
- (待填)

### Surprises
- (待填)

### Recommendation for the real build
- (待填)

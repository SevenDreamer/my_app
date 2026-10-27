# 内置 Hermes 运行时（M-R）— 自带 Ubuntu rootfs + proot

> 状态：v0.1 方案（2026-10-27）｜前置：`ANDROID_HERMES_CLIENT.md`、`MOBILE_HERMES_BLUEPRINT.md`、
> `HERMES_GATEWAY_PROTOCOL.md`｜样板：DSHA（MIT，读码结论见蓝图 §2.1）
> 动因：Hermes 官方 Termux 包当前损坏（官方文档挂告示 "Termux is currently broken"，
> 用户实测安装跑不起来）——手机本地运行时不能等上游修复，改走 **自带系统**。

## 0. 一句话

**照 DSHA 的路：APK 外置下载 Ubuntu rootfs + proot 伪根，把 hermes-agent（MIT）
烘焙成运行时层装进去，gateway 监听 `127.0.0.1:9120`——my_app 的「检测本机网关」
零改动直接接上。**

## 1. 取舍表

### 1.1 运行时载体

| 路线 | 说明 | 结论 |
|---|---|---|
| **A. 自带 Ubuntu rootfs + proot** | DSHA 同款；完整 glibc，官方 `install.sh`（glibc Linux）原生可用 | ✅ 推荐 |
| B. Termux 源码装 | 绕过坏包自己装；但 bionic 环境的原生模块风险同官方包 | ⚠️ 顺手可试，不押注 |
| C. 只连远程 gateway | 现在就可用（G1.1），但手机不自足 | ✅ 保留为兜底 |

### 1.2 rootfs 分发

| 路线 | 说明 | 结论 |
|---|---|---|
| **A2. 按需下载** | 复用 **live2d 资产按需下载基建**（上游刚落地的那套），APK 保持 24MB | ✅ 推荐 |
| A1. 打进 APK/分包 | DSHA 278MB 路线；安装包大、更新笨 | ❌ |

### 1.3 hermes 怎么进 rootfs

| 路线 | 说明 | 结论 |
|---|---|---|
| **B1. 预烘焙运行时层** | CI 里装好 hermes+Node+依赖 → 打成 `hermes-runtime.bin` 覆盖层（DSHA `dsh-runtime.bin` 同款），离线确定性安装 | ✅ 推荐 |
| B2. 首启在线装 | 解包后跑官方 `install.sh` | ❌ 依赖网络/慢/会挂（正是这次的教训） |

### 1.4 proot 来源

| 路线 | 说明 | 结论 |
|---|---|---|
| C1. 自编译 Termux proot 分支 | GPL-2.0；独立可执行分发 + COPYING 保留 | ✅ 推荐（先走这条） |
| C2. DSHA 的 libproot.so 装载技巧 | proot 编成 .so 走 jniLibs + loader（疑似绕 exec/W^X 限制） | 🔧 C1 受阻时的兜底（`tools/build-low-proot.py` 是现成参考） |

## 2. 许可红线（已核实）

| 组件 | 许可 | 处理 |
|---|---|---|
| **hermes-agent** | **MIT**（Nous Research 2025，LICENSE 实读） | ✅ 可烘焙可分发，保留版权声明 |
| **proot**（Termux 分支） | **GPL-2.0**（DSHA THIRD_PARTY_NOTICES 实读） | 独立可执行/独立 .so 分发 + `COPYING` 保留——**mere aggregation，不链接进闭源代码**（照抄 DSHA 模式） |
| Ubuntu rootfs | 各包许可证汇编 | 附 notices；来源 Canonical `ubuntu-base-24.04-arm64`（约 30MB 压缩） |
| proroot（DSHA 专有二进制） | 上游专有 | **不搬**，只用开源 proot |

## 3. 架构

```
┌────────────────────────────────────────────────┐
│  my_app（Flutter，已有）                          │
│  ├─ Hermes 功能域（G1/G2，已有）                   │
│  ├─ 运行时管理（新增 M-R）：安装/启动/停止/看门狗/日志 │
│  └─ 「检测本机网关」→ ws://127.0.0.1:9120/api/ws ✅已就绪
└───────────────┬────────────────────────────────┘
                │ Process.start（app 私有目录）
┌───────────────▼────────────────────────────────┐
│  proot（GPL-2.0 独立二进制）                       │
│  └─ Ubuntu 24.04 rootfs（按需下载 + 事务式解包）     │
│     └─ hermes-runtime 层（预烘焙：hermes+Node+依赖） │
│        └─ hermes gateway/webapp :9120             │
└────────────────────────────────────────────────┘
```

- 解包学 DSHA 的事务式思路（简化版）：校验 → 新目录解压 → 原子改名提交；
- 进程管理学 DSHA：**前台服务 + 看门狗**（web 掉了自动拉起；慢启动不误杀）；
- rootfs 与 hermes 层**独立版本号分包**（学 DSHA 分包更新：换 hermes 不重下 rootfs）。

## 4. 里程碑

| 期 | 内容 | 验收 |
|---|---|---|
| **R0 PoC** | 手机上手动跑：ubuntu-base + 自编 proot + 手装 hermes → gateway 起来 | my_app「检测本机」连上并聊天 |
| **R1 运行时资产** | rootfs 下载器（复用 live2d 基建）+ 事务式解包 + SHA 校验 | 首次进入一键装好环境 |
| **R2 proot 接入** | proot 二进制（GPL 合规 + notices）+ 启动/看门狗/日志 | 杀掉进程自动拉起 |
| **R3 体验** | 运行时卡片（安装/启动/停止/状态/日志）+ 与连接页打通 | 全程不碰命令行 |
| **R4 预烘焙** | CI 烘 `hermes-runtime.bin`（版本化），离线安装 | 断网重装可用 |

## 5. 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| 体积 | rootfs ~30MB + hermes 层预计 150-250MB 下载 | 按需下载 + 分包；提示用户流量 |
| proot 性能（ptrace 开销） | 启动/IO 变慢 | hermes 是 IO 型负载可接受；DSHA 也是默认 proot |
| exec W^X / SELinux | 个别 ROM 禁止执行 app 数据里的二进制 | C2 的 .so 装载技巧兜底（DSHA 实证可用） |
| MIUI/各家杀后台 | gateway 挂 | 前台服务 + 看门狗 + 通知栏常驻（对齐 DSHA） |
| 仅 arm64 | 32 位机不支持 | 与 DSHA 同限制，明示 |
| 升级漂移 | hermes 更新频繁 | R4 分包版本化，运行时层独立更新 |

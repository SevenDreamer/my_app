# R0 PoC — 内置运行时链路验证（rootfs + proot + hermes）

> 验证目标：手机上**不依赖 Termux 的 hermes 官方包**（当前损坏），用自带 Ubuntu rootfs
> 跑起 hermes gateway，让 my_app「检测本机网关」连上并聊天。
> 方案与后续里程碑见 `docs/EMBEDDED_HERMES_RUNTIME.md`。

## 为什么借 Termux 的壳跑 PoC

PoC 只是借 Termux 提供 **proot 与 bash**（Termux 本体是好的，坏的只是 hermes-agent 包）。
产品化时（R2）这两个能力由 my_app 自带（proot 独立二进制 + 本地进程管理），不再需要 Termux。

## 步骤（K80 / 任意 arm64 Android 10+）

1. 装 Termux（F-Droid 版），把本目录两个脚本放进 Termux 可访问处（如 `~/`）：

   ```bash
   # 电脑侧（手机连 USB）：
   adb push poc.sh /sdcard/ && adb push enter.sh /sdcard/
   # Termux 侧：
   cp /sdcard/poc.sh /sdcard/enter.sh ~/ && cd ~
   ```

2. 一键准备环境（首次 15-30 分钟，需网络）：

   ```bash
   bash poc.sh
   ```

   其中：ubuntu-base **24.04.5** arm64（SHA256 校验）、解包到 `~/hermes-runtime/rootfs`、
   假 root 进容器装 curl/git、官方 `install.sh`（MIT）装 hermes、开 `webapp.enabled`。

3. 进入并启动 gateway：

   ```bash
   bash enter.sh
   ```

   看到 gateway 起来后**保持终端运行**。

4. 打开 **my_app（dev.20+）→ Hermes → 检测本机网关** → 应显示「已连接」→ 会话列表 → 新会话 → 发消息。

## 验收清单

- [ ] `poc.sh` 全程零报错（rootfs SHA 校验通过）
- [ ] `enter.sh` 里 `hermes gateway` 启动成功
- [ ] my_app「检测本机网关」自动填 `ws://127.0.0.1:9120/api/ws` 并连接成功
- [ ] 会话里发消息收到流式回复（顺带真机验证 G1/G2 的字段解析）
- [ ] 记录：安装总耗时 / rootfs+hermes 体积 / 消息延迟体感

## 已知边界（PoC 不处理）

- 脚本依赖 Termux 的 proot（GPL-2.0）；产品化由 my_app 自带 proot（合规模式见方案文档 §2）
- gateway 生命周期 = 终端生命周期；看门狗/前台服务是 R2
- 预烘焙运行时层（免在线安装）是 R4

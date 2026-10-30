# DSHA 重构计划 —— 完全重构为 Dart/Rust，融合进 my_app

> 状态：v0.1（2026-10-27）｜工作区：`D:\Projects\dsha-refactor`（MIT，保留版权 + THIRD_PARTY_NOTICES）
> 索引：GitNexus 已建（42,901 节点 / 157,754 边 / 1,649 流）——动刀前先查影响面
> 关联：`EMBEDDED_HERMES_RUNTIME.md`（M-R 并入本线）、`MOBILE_HERMES_BLUEPRINT.md`（M-A 并入本线）

## 0. 决策记录（用户拍板 2026-10-27）

1. **语言级重写 → Dart/Rust**（不是结构式清理）
2. **Python 保留**：先盘点 → 重排架构、剥依赖、现代化
3. **按进度分层融合**进 my_app（每批完成即合）
4. **落位 my_app `packages/`**（Rust 进 `rust/` workspace）
5. **备份数据格式 / 配置兼容旧 DSHA**（v5 备份 + rc1 配置迁移是兼容对象）
6. **DSH 插件市场保留**（plugin 七件套 ~4.8k 行入范围）

## 1. Python 资产清单与依赖审计（批次 A 成果①）

**结论：13 个运行时脚本顶层依赖全为标准库；另有两个运行时 pip 包**
（`adb_shell_wifi`、`spake2`）以**函数体内惰性导入**方式使用（顶层 grep 看不见，
`check_deps()` 守门）——它们在 rootfs 里随运行时层安装。

| 支柱 | 文件（行数） | 去向 |
|---|---|---|
| ADB 桥 | adb-shell(515) · device-shell-policy(336) · adb-pair(175) + adb-setup.sh(119) | **保留+现代化**（批次 A）；宿主侧等价物 Rust 重写（批次 C） |
| 备份 | backup-engine(1005) · backup-plugin-graph(273) | **保留**（决策⑤兼容源）+ 现代化 |
| 插件市场 | plugin-manager(1295) · register-builtin-plugins(1161) · plugin-transactions(927) · plugin-lifecycle(776) · plugin-dependencies(380) · plugin-network(158) · plugin-capabilities(85) | **保留+现代化**（决策⑥） |
| 配置迁移 | rc1-migration(416) | **保留**（决策⑤兼容源） |

**架构着力点**：多个文件用 `importlib.util` 动态加载相邻脚本（隐式耦合链）——
现代化的第一刀：改为显式包结构/接口注入。
**对照资产**：`tools/` 下 20+ 测试脚本（test-backup-engine 959 行…）是行为对照基准。

## 2. 目标架构（my_app）

```
my_app/
├── packages/
│   ├── hermes_gateway/        ✅已有（/api/ws 客户端）
│   ├── hid_gamepad/           ✅已有
│   └── dsha_core/             🆕 Dart：安装流水线编排、备份/配置 API、兼容层
├── rust/                      🆕 扩展 workspace：
│                              AdbBridge→Rust、proot 进程管理、vscreen(批次D)
└── 运行时资产层（并入 hermes-runtime 分发）：
    └── python/   ← 保留的 Python（显式包结构 + 类型标注 + 共享工具抽出）
```

## 3. 批次表

| 批次 | 内容 | 状态 |
|---|---|---|
| **A** | Python 盘点定稿 ✅ + **ADB 四件套现代化**（显式包结构/剥 importlib 耦合/类型标注） | ✅ 完成（pair/shell/policy/_adb_common/setup.sh + README） |
| B | `runtime/`（Java 30 文件）→ Dart/Rust：安装流水线、事务解包、运行时选择 | ✅ **Dart 编排层**（install_stage/probe/process/pipeline + sensitive_data/shell_quote）+ **Rust 解包层**（dsha_runtime：limits/fs_identity/signed_members/control/budget/legacy_tar/archive/cold_split） |
| C | `bridge/` 设备能力门（配合蓝图 M-A 三态/白名单） | ✅ **Dart 编排**（adb_bridge 323/virtual_screen_start/bridge_connection_descriptor/bridge_handshake）+ **Rust 系统面**（device_shell_policy 780/device_file_operations 373/android_device_files ~520）；`cargo check --target aarch64-linux-android` 双绿 |
| D | `vscreen/`（26 文件 8,379 行）→ Rust/Dart：锚点证明/观察控件/无障碍 | ✅ **D1 证明栈**（Rust vscreen_anchor_proof 530 + Dart target_evidence/peer_proof）；**D2 像素/观察**（observed_control/observed_pixels/pixels/display_session/support）；**D3 契约工具+Core 服务面**（policy/input_policy/failures/core_identity/handshake/request_scope/journal/bootstrap/proc_identity/core 660）；**D4 输入/无障碍**（stroke/input/accessibility/a11y_support）；**D5 通道+Manager**（channels/native_controls/semantic_adapter/manager_support/bridge_request/manager 1700）；**D6 UI 逻辑**（preview_input_gate/touch_feedback/coalescing_poller/preview_view_logic/ui_outcome/previews_core/node_panel_logic；View 壳归 Flutter 侧按 DESIGN.md 重写）。接线遗留：`requestAt` HTTP 客户端（HttpProtocol.Head）、`readBootstrap` 进程编排、Android 缝（DisplayCreator/事件注入/无障碍节点） |
| E | 插件市场七件套现代化（决策⑥）+ 备份 v5/rc1 兼容层（决策⑤）+ tools 构建链迁移 | ✅ E1 备份/rc1 兼容层（backup_engine/backup_plugin_graph/rc1_migration）；E2 七件套（register_builtin_plugins+builtin-plugins.json / plugin_manager / plugin_transactions / plugin_lifecycle / plugin_dependencies+runtime-tools.json / plugin_network / plugin_capabilities + 三个 .cjs 助手）；E3 tools 构建链 ✅（63 件：G1 运行时构建 / G2 准备链 / G3 测试夹具 / G4 prepare 小件 / G5 CI/发布链 / G6 generate / G7 recovery / G8 audit/check / G9 Java 格式化+文案迁移 / G10 测试运行器 / G11 mjs/js/c 资产+prepare 四小件） |

> 批次 B 遗留接线项（不阻塞批次推进）：`LocalEnvironment`/`InstallProcess.read`
> （proot 运行时接线）、`TrustedAssetFs` 的 Android 实现（fd 出生身份快路径）、
> `collision_key` 已入 limits（NFC）。错误代号契约全量保留（COLD_SPLIT_* / TAR_* /
> GZIP_* / ARCHIVE_* / INSTALL_*）。

## 3.1 F 批：产品融合（2026-01 起，进行中）

> 拍板（2026-10-28）：F1 起手 / Android 系统面先 Dart 抽象+桌面桩再补原生 /
> 新 feature「DSH 系统」登记 registry（desktop limited / mobile full）。
> 顺序：F1 运行时系统 → F2 被控端屏幕 → F3 插件市场宿主面 → F4 备份/恢复宿主面。

| 步 | 内容 | 状态 |
|---|---|---|
| F1-1 | `InstallProcess.read()/Lines`（有界逐行读取+回收语义，行 16 KiB/4,096 字双阈值脱敏、私钥掩码） | ✅ 冒烟 5/5 |
| F1-2 | `runtime_bootstrap.dart`（RuntimeBootstrap 接缝 + AndroidGroupMap 逐表 + DesktopBootstrap + BasicToolsInstaller）+ `local_install_environment.dart`（1:1 委托）+ execute() 接 read | ✅ 冒烟 ENV_SMOKE_PASS |
| F1-3 | 「DSH 系统」feature 壳：registry 登记 + MVVM 页面接 InstallRepository 语义 | ✅ analyze 绿 + 启动冒烟 + **真机渲染核验**（红米，页面/六步/引擎行正常，「未就绪」诚实路径符合预期） |
| F1-4 | hermes-runtime 烘进 rootfs + Android 原生接线（Rust 解包 FFI / proot argv / TrustedAssetFs） | 🔨 F1-4a Rust FFI ✅（std_fs 真实现 + `dsha_extract_archive` extern "system" + dart:ffi 桥 RustUnpacker；抓真 bug：`Decompress::new(true)` 误当 zlib 头致 GZIP_DEFLATE、read_file 弱身份守卫）+ F1-4b 接线 ✅（`ArchiveExtractor` 接缝 + RustArchiveExtractor/TarCommandExtractor 双实现 + VM 显式选型 UI 可见 + **Android .so**：NDK 27 链接 libdsha_runtime.so 入 jniLibs，`dsha_extract_archive` 符号核验；19 Rust 依赖入 NOTICES）+ **真机核验**：libdsha_runtime.so 在 Android 加载成功（「解包引擎：Rust 硬化解包」UI 可见）；F1-4c 烘层 ✅ **九件全落**（~254MB）：offline-rootfs.bin 85.5MB（ubuntu-base+node24）、dsh-runtime.bin 127.4MB（17 ARM64 原生件）、ubuntu-tools 19.5MB、glibc-python 12.8MB、adb-wheels 9.96MB（按锁 15 wheel）、pnpm/python-support/ca-certs/licenses；新工具 build_runtime_rootfs/build_glibc_python/build_adb_wheels 入 tools/；余：资产部署接线（VM 三接缝供料）→ 手机端到端 |
| F1-5 | proot 容器 runner：jniLibs 五件现货（GPL/LGPL 入 NOTICES）+ `proot_runner.dart`（argv/env/别名件契约逐字）+ Kotlin nativeLibraryDir channel + VM/UI 接线 | ✅ 双绿 + SMOKE_PROOT_RUNNER_PASS + 发版 dev.24+68 |
| F2 | Manager `requestAt` HTTP + `readBootstrap` + Activity/Preview/Overlay/Foreground Flutter 重写（D6 契约件已备） | ⬜ |
| F3 | 插件市场宿主面（E2 七件套跑 guest，宿主 UI + bridge 命令封装） | ⬜ |
| F4 | 备份/恢复宿主面（E1 v3/v4 归档 + rc1 迁移的管理 UI） | ⬜ |

> F1 接线余缝（Android 原生轮补齐）：`prepareRuntimeTools`（随包证书/命令入口，
> RuntimeTools.java 未移植，当前如实抛 UnimplementedError）、解压换 Rust FFI、
> runner 换 proot argv、`/proc` 真实源。真 bug 修复：WSL bash argv 吞引号
> （PITFALLS #31）、poller 缺内部截止期、`bash -s` 参数表 126。

## 4. 合规（每批必做）

- MIT：保留 DSHA 版权声明 → 汇总进 my_app `THIRD_PARTY_NOTICES.md`（新建）
- proot（GPL-2.0）：独立分发 + COPYING（见 EMBEDDED_HERMES_RUNTIME §2）
- proroot（上游专有）：不搬

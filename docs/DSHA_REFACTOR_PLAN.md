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
| **A** | Python 盘点定稿 ✅ + **ADB 四件套现代化**（显式包结构/剥 importlib 耦合/类型标注） | 🔨 进行中 |
| B | `runtime/`（Java 30 文件）→ Dart/Rust：安装流水线、事务解包、运行时选择 | ⬜ |
| C | `bridge/` AdbBridge(720) → Rust：设备能力门（配合蓝图 M-A 三态/白名单） | ⬜ |
| D | `vscreen/`（26 文件 8,379 行）→ Rust：锚点证明/观察控件/无障碍 | ⬜ |
| E | 插件市场七件套现代化（决策⑥）+ 备份 v5/rc1 **兼容层**（决策⑤）+ tools 构建链迁移 | ⬜ |

## 4. 合规（每批必做）

- MIT：保留 DSHA 版权声明 → 汇总进 my_app `THIRD_PARTY_NOTICES.md`（新建）
- proot（GPL-2.0）：独立分发 + COPYING（见 EMBEDDED_HERMES_RUNTIME §2）
- proroot（上游专有）：不搬

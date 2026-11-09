# Linux 底座方案（容器域）

> 2026-11-06 与用户共议成型。定位：my_app 的独立域「Linux 底座」——
> 单 Ubuntu 容器跑 agent 的通用底座。本文为方案与分期账，实批后按期推进。

## 一、定位与形态

**一句话**：一个 Ubuntu proot 容器（单容器），作为 my_app 里跑各种 agent
（DeepSeek/DSH、Hermes、后续其他）的"系统底座"——像 Linux Deploy，
但与工具箱融为一体：app 内建、可监测、可自动化装 agent。

**已定决策**（2026-11-06 共议）：

| # | 决策 | 理由 |
|---|---|---|
| D1 | **单容器**（全家桶一系统） | agent 互助（DeepSeek 修 Hermes）；proot 下多容器隔离只有文件级，不值得换；耗电看 agent 进程不看容器数；坏了靠**快照回滚**（rootfs=目录，tar 即快照） |
| D2 | **Ubuntu 先行**，发行版矩阵后置 | 等 Hermes 手机端正式版、看 dsh-go 连接形态再扩；Ubuntu 与 dsh-go rootfs 同源（烘制链现成） |
| D3 | **架构默认原生**，x86 模拟按需 | arm64 手机装 arm64 rootfs（性能满血）；x86-only 软件用 QEMU user-mode 镜像（性能降 2-5x，仅按需装） |
| D4 | **四层入口**：app 终端（主）/ agent 对话 / SSH（电脑可连）/ 文件管理 | dsh-go 的 terminal/ssh/files 件随整壳落位，底座泛化后直接复用 |

## 二、分层架构

```
应用层：agent 模板（Hermes 镜像 / DSH 镜像 / 开发环境…）
        ↕ 标准化安装器（看 dsh-go 如何装 DSH → 通用化：镜像模板 + 安装脚本）
镜像层：Ubuntu rootfs（原生架构）；[后置] 发行版 × 架构矩阵（native | x86-QEMU）
底座层：proot 启动器 + 实例管理 + 快照/回滚 + 状态监测
        （dsh-go runtime 链泛化：rtbuild.py 烘制规格 / RuntimeInstaller /
          DshProcess 启动模板 / 七态状态机）
```

**与 DSH 域的关系**：dsh-go 的 runtime 链（批次 3 搬入的 Kotlin 全域）是底座
的雏形。底座独立化 = 把"DSH 专用运行时"泛化为"通用容器"，DSH 成为底座上的
第一个 agent（其整壳交互仍留 DSH 域）。归属迁移待 P0 实批时定（runtime 域
代码在 my_app/runtime 命名空间，泛化不搬家、只扩职责）。

## 三、分期计划

| 期 | 内容 | 验收 |
|---|---|---|
| **P0 底座独立化** | registry 新增「Linux 底座」域；实例管理（创建/启动/停止/删除）；快照/回滚；app 内终端接入；系统状态卡片（CPU/内存/磁盘/运行态） | my_app 里能建 Ubuntu 容器、终端进得去、坏了回滚得了 |
| **P1 agent 标准化安装** | 观察 dsh-go 在容器内装 DSH/连接远端的做法 → 通用安装器：安装模板（Hermes/DSH）+ 选择性自动化装软件；安装清单可勾选 | 勾选「Hermes」→ 容器内自动装好、可用 |
| **P2 监测与守护** | 状态面板常驻（后台通知已有个先例）；agent 进程按需启动/休眠（耗电策略）；崩溃自检（自测器链复用） | 常驻不过热、挂了能感知 |
| **P3 矩阵扩展**（后置） | 发行版扩展（Debian/Alpine…）；x86-QEMU 镜像槽位；ttyd web 终端 | 按需 |

## 四、与「下载正式 dsh-go app」的关系

用户计划手机上另装官方 dsh-go 裸 app 体验对照（ccch1mneyyy/dsh-go 发布版）。
注意三条：

1. **包名不同可并存**（`com.example.my_app` vs `io.github.ccch1mneyyy.dsh_app`）；
2. **运行时别同时启动**：两个 app 各自想跑 proot/DSH 容器，端口与前台服务
   会打架——对照体验时一开一关；
3. 裸 app 的更新器拉的是上游 GitHub（我们融合版已屏蔽那套）——裸 app 里
   该点更新就点，不影响 my_app。

对照目的：体验成品细节（安装引导/运行时交互/桌宠形态），为 P1 的安装器
与后续统一体验（批次 8）提供参照。

## 五、决策落账（2026-11-06 用户批）

1. **入口形态**：registry 独立项（与 DSH 并列）——底座是中枢级能力 ✅
2. **runtime 归属**：**语义归底座、代码暂不改名**（RuntimeInstaller/DshProcess
   等 178 件 Kotlin 保留原名，文档注释明确"底座引擎"；全链改名待第二个
   容器产品出现再议）✅
3. **P1 首发模板**：**双轨并行**——现有 dsh-go 专用系统照跑（不破坏已验证
   链），同时在新底座容器里琢磨「DSH 当应用装进去」（dsh-go 烘制规格反推
   = 安装器第一模板）；**DSH 模板打头阵、Hermes 模板跟上** ✅

## 六、P0 详细设计（2026-11-06，待批开工）

### 功能清单

| # | 做什么 | 实现什么 | 复用现状 |
|---|---|---|---|
| 1 | **registry 独立域「Linux 底座」** | `lib/features/linux_base/`（MVVM + ChangeNotifier，my_app 域铁律）；FeatureEntry(id: linux_base, LucideIcons.box, mobile: full, desktop: limited) | 注册表/平台能力声明惯例 |
| 2 | **系统总览页** | 一屏：运行态（七态）/ 版本（runtimeVersion）/ CPU·内存·磁盘 / 快照列表 / 操作按钮排 | `dsh/runtime` getStatus；AppSection 卡片 |
| 3 | **实例管理 = 接管现有主系统** | 启动/停止/安装重建/崩溃修复（按钮化） | DshProcess/DshService/RuntimeInstaller；**LastKnownGood 恢复 + SafeMode moveAside 已有能力接按钮** |
| 4 | **快照/回滚**（唯一新能力） | 手动快照（rootfs 目录打 tar.xz → filesDir/snapshots/）、列表（保留 2-3 个）、一键回滚、改坏前自动快照；Kotlin `SnapshotManager` + 通道方法（snapshot/restore/list/delete） | TarExtractor/xz 库已有；与 LastKnownGood 并存（LKG=自动「最后已知良好」，快照=显式版） |
| 5 | **系统状态监测** | 七态 + proot/dsh/node 进程 + CPU/内存（读 /proc）+ rootfs 磁盘占用 + 运行时长；Kotlin stats 采集 → Dart 卡片 | 进程归属（RuntimeProcessOwnership）已有 |
| 6 | **终端接入（零新码）** | 底座页进终端 | `DshClient TerminalShell`（DSH 引擎 WebSocket 终端，整壳已验证） |
| 7 | **归属标记** | runtime 链头部注释「Linux 底座引擎，见 LINUX_BASE_PLAN.md」 | — |

### 关键设计点

- **主系统 = 现有 DSH 运行时的 rootfs**（单容器决策 D1）：底座不另建系统，
  是给这个系统一个通用管理面板；DSH 整壳照常用它（双轨不破）。
- **快照空间预算**：rootfs 解包约 800MB → 快照保留 2-3 个 + 空间提示；
  压缩用现成 xz（tar.xz，与 rootfs 发行格式同族）。
- **终端依赖 DSH 引擎常驻**：P0 阶段主系统=DSH 系统，天然满足；无 DSH
  的裸 shell 通道（Kotlin 直起 proot sh）留 P2+ 再议。

### P0 不做（防蔓延）

多实例 / 多发行版 / x86-QEMU / agent 安装器（P1）/ 休眠耗电策略（P2）/ ttyd（P3）。

### 风险项

1. 快照打包 800MB 目录耗时（分钟级）——异步任务 + 进度回传（照 RuntimeInstaller 形态）；
2. `/proc` 状态采集直读（不经 proot）——仅本机进程可见性验证一次即可。

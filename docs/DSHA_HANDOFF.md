# DSHA 重构线 · 会话交接文档（HANDOFF）
> ⚠️ **2026-11-04 更正**：本文「只学设计不抄码」「DSHA 线继续推进」等共识已被
> 用户拍板取代（dsh-go 全量融合、直接搬码、AGPL 传染、DSHA 线冻结）——
> 一切以 `docs/DSHGO_MERGE_PLAN.md` 为准，本文仅作历史/设计参考。


> 交接时点：2026-10-30 · 当前版本 **1.3.0-dev.26+70**（Patch 3 已挂）
> 本文给接手的 Hermes：读完即可继续 F1 线。总台账见 `docs/DSHA_REFACTOR_PLAN.md`，
> 坑档 `docs/PITFALLS.md`，行为契约红线见 `.agents` 技能 `third-party-refactor`。

## 一、现在的活：「DSH 系统」真机六步点亮（F1 线收尾）

**目标**：手机上「DSH 系统」页六步全绿（Linux 环境 → 基础工具 → Node.js →
pnpm → dsh → 运行补丁）。离线运行时已全内置（APK ~277MB），proot 容器已跑通。

**工作循环（已建立，照做）**：
1. 改代码 → `flutter analyze` + `dart analyze`（packages/dsha_core）双绿
2. 纯 Dart 改动 → `tool/patch.sh 1.3.0-dev.26+70`（热更，勿裸跑 shorebird patch
   ——会丢 SENTRY_DSN，PITFALLS #32）；动原生/资产/Manifest → bump pubspec +
   `tool/release.sh` + tag + GitHub prerelease（三件套同号，manifest 回读核验）
3. 用户手机「修复并检查」→ 点「上报诊断」按钮
4. **拉 Sentry 诊断包**：sentry_mcp 工具（org `comqike`）→ SEARCH_ISSUES
   `dsha-diagnostics` → GET_SENTRY_RESOURCE `MY-APP-3` → 读 `dsha` context 的
   `details`/`log` 字段（六步现场全在里面，勿让用户手抄）
5. 对症修 → 回到 1。改完直接 `git push origin main`（用户已授权直接推）

## 二、真机现状（🎉 六步全绿，2026-11-02 dev.26+70 Patch 8 收官）

六步全过：Linux 环境 / 基础工具（curl+git+Python 3.12.3）/ Node v24.16.0 /
pnpm 10.34.5 / dsh 0.2.1-rc.2 / 运行补丁（DNS+会话+局域网+用户组）。
收官正解 = **L2S 模式**（proot `--link2symlink`：原版 install 路径
LaunchSpec.hardlinks 默认 false，link 仿真为 symlink，dpkg 备份才不炸）。

## 三、下一步（按序）

1. **六步已全绿收官**——下一步方向由用户定：M-R（Hermes 进 rootfs，
   最初动机）/ F2 Manager 宿主面 / F3 插件市场 / F4 备份恢复
2. 补丁链 `applyPatchChain`（四专项）——仅升级场景需要（dsh-runtime 烘制
   已带补丁），优先级可后置
3. F2/F3/F4（Manager 宿主面 / 插件市场宿主面 / 备份恢复宿主面）——见台账

## 四、架构速览（F1 线落位图）

- `packages/dsha_core/lib/src/install/`：安装链全量（install_process 有界
  逐行读+stderr 并线、install_probe 六步探针、install_stage 状态模型、
  install_pipeline 编排、runtime_bootstrap DesktopBootstrap+双流解包、
  runtime_tools 命令入口/证书/DNS、proot_runner argv 契约、rust_unpack
  后台隔离岛解包）
- `lib/features/dsha_system/`：MVVM 页（view_model + page + dsha_asset_staging
  资产暂存清单）
- `assets/dsha/`：九件烘制资产 + guest 脚本 ×6 + licenses（大件 gitignored，
  由 `packages/dsha_core/tools/` 确定性重烘）
- `rust/dsha_runtime/`：Rust 解包引擎（legacy_tar/cold_split/std_fs…）
- Android：jniLibs 六件（libdsha_runtime.so + proot 全家桶），MainActivity 有
  `my_app/runtime` channel（nativeLibraryDir/dataDir/deviceDns）

## 五、关键契约（别弄丢）

- **proot argv**：`-L --kill-on-exit -0 --rootfs=… --cwd=/root` + 九绑定 +
  env `PATH=/root/dsh-bin:…`/`PROOT_LOADER`/`LD_LIBRARY_PATH`（proot_runner.dart）
- **命令入口全在 `/root/dsh-bin/`**（wrapper 字面逐字，runtime_tools.dart）
- **探针协议**：`DSHA_CHECK_RESULT:<key>:<code>`；detail 模板 `%s：正常/失败（退出码 %s）/未收到结果`
- **「不覆盖用户升级的 Node/dsh」**：3/5 步修复故意不修；dsh 只做**缺失补装**
- **cold_split 双流**：base=offline-rootfs.bin + runtime=dsh-runtime.bin（初装合成）
- 资产清单唯一来源：`DshaAssetStaging.files`（**加资产必加清单**——本轮踩过）

## 六、本轮新坑（详档 PITFALLS #31/#32 + 下述）

1. **shod 输出通道给日期串打码**（`6.4+202****0113`）——钉版文件名/版本号
   **禁止从工具输出抄**，进程内解析索引重建（runtime-asset-baking 技能有专条）
2. **shorebird patch 必须带 dart-define**——走 `tool/patch.sh`，勿裸跑
3. **Java→Dart raw 字符串转义加倍**：Java `"^\\d+\\."`（2 层）→ Dart raw 是
   `r'^\d+\.'`（1 层），写成 4 层就永不匹配（码点验证法：`[ord(c) for c in seg]`）
4. **Dart 无 redirectErrorStream**：要手动把 `process.stderr.listen` 并进
   行流（本轮补上——此前 apt/node 报错全丢）
5. **AGP 默认 extractNativeLibs=false**：可执行 .so 必须
   `packaging.jniLibs.useLegacyPackaging = true` 落盘（proot 从
   nativeLibraryDir 执行，W^X 规则）
6. **MSYS `/d/` 路径幻影**：Windows Python 永远用 `D:/` 原生路径
7. `tool/release.sh` = 发版一键（Shorebird+R2+manifest）；`tool/patch.sh` =
   热更一键；三件套（pubspec/tag/GitHub prerelease）同号

## 六·五、上游基线（跟上游更新时从这里 diff）

- **源**：`https://github.com/DSH-APP/DSHA`（MIT），本地检出 `D:\Projects\dsha-refactor`
- **基线**：`98bd97a276b0d244398de6b8b4c36b71403486cf`（2026-10-26，github-actions）
- **版本**：`v0.2.1-rc.2-10-g98bd97a`（= tag v0.2.1-rc.2 后 10 提交；与我们烘的
  dsh-runtime 0.2.1-rc.2 对版）
- **跟进法**：`git fetch && git log 98bd97a..origin/main --oneline` 看上游增量，
  按 `third-party-refactor` 批次法吸收（行为契约逐字、每批双绿 + notices）

## 六·六、生态观察：dsh-go（第三方 DSH 客户端，⚠️ 只学设计不抄码）

- **仓库**：`github.com/ccch1mneyyy/dsh-Go`（2026-10-25 创建，一周 ~4.7k stars）
- **是什么**：DeepSeek Harness 的第三方 Android 客户端（Flutter + Kotlin），
  「App 内安装 Ubuntu/Node/DSH 运行环境（无需 Root/Termux）」——**与我们
  F1 线同构的路线**，另带遥控电脑（SSH/DSH Remote）、插件 JSON 视图声明
  （App 渲染声明、不执行插件代码）、手机操控（读屏/点按/输入）。
- **⚠️ 合规**：主仓 **AGPL-3.0**（与 Coopanion 同规格：只学设计不抄码）；
  仅 `sdk/plugin-kit` + `examples/` 为 MIT 可用。
- **可借鉴面**：`packages/dsh_client/`（DSH Web API Dart 客户端——
  F2-4 requestAt 的协议参考）、`runtime/` 运行时打包（与我们烘层互证）、
  插件原生视图声明（F3 插件市场 UI 设计参考）。
- 关键词：dsh-plugin 生态已有第三方原生插件工具包（插件互通话题的旁证）。

## 七、环境要点

- Flutter `/d/flutter/bin`（export PATH）；Android：`export ANDROID_HOME=D:/AndroidSdk
  ANDROID_SDK_ROOT=D:/AndroidSdk JAVA_HOME="C:/Users/v_qzxgqiu/scoop/apps/temurin17-jdk/current"`
- Dart/Flutter 双绿门槛 + 烟测脚本在 `packages/dsha_core/tool/smoke_*.dart`
- 测试机：红米 K80 Pro（Android 16，24122RKC7C）——诊断包设备
- Sentry：org `comqike` 项目 `my-app`；诊断 issue **MY-APP-3**（dsha-diagnostics）；
  ANR 事件看 MY-APP-2；DSN 在 `tool/sentry.env`（gitignored）
- Shorebird app-id `7a0c80c7-33d1-4c23-9f4a-94686b28ea30`；patch 走 stable 通道

## 八、全量搬码批次（进行中，2026-11-04）

- **已搬**：vscreen 链 + 依赖闭包 **~150 件 Java**（vscreen/bridge/capabilities/screen/
  device/diagnostics/util/runtime 部分）+ 第三方库（gson/snakeyaml/bcprov/
  appcompat/webkit/material）已入 gradle。编译收敛曾达 192→1（验证路径可行）。
- **豁免域已剪**（159 件）：backup/Plugin/Web/Dsh/Lan/Update/Skill/Builtin/Recovery/
  Gecko/Browser/Agent/Cold/Trial/Automatic/Pty/Terminal —— 后置规划 + termux 依赖。
- **剩 185 错 = 深耦合长尾**：vs 链引用被剪件的 3-5 处（AdbBridge:401→backup、
  ProotBootstrap→runtime.Xxx、AdbWheelPaths→backup）——需逐处剪枝适配或补回真依赖。
- **决策点（问用户）**：①终端功能（PtySession 等，需 termux terminal-view 依赖）
  要不要？②backup 引用处：剪枝 stub 还是补回被引类？
- Kotlin 真身（ShizukuShell/ShellService/MainActivity/StartupCrashRecorder/
  RuntimeForegroundService）优先于同名 Java（循环搬运会拉回重名，须删）。

## 九、搬码收尾状态（2026-11-04 深夜）

- **重置基线**：500 件全量重拷（ui/剪、终端件剪、Kotlin 真身优先）+ vscreen/ 27 件保护。
- **剩 171 错** = vscreen 件引用被删的支撑件（ConfigStore/DiagnosticRepository/
  EnvironmentAccess/RuntimeExecution/InstallPipeline/BasicToolsInstaller 等 core/util/runtime
  件——「删重灾」收敛时误删）。
- **下轮收尾**（一轮）：从原版**恢复支撑件**（vs 引用闭包，非删 vs）→ 编译归零 → 发版。
  切忌再「删重灾」删进 vs/ 保护目录（本轮教训：VirtualScreenChannels 等被误删已恢复）。
- 收敛实证：单调降可达（189→52），但正确终法=恢复支撑件闭包。
- DSH 客户端线（dsh_api + launcher + 对话页）已全链代码就绪（ca70c29/d6bad9b），
  发版被本编译长尾卡着。

### 收敛终态（2026-11-04 终）：~400 件在库，175 错集中在
capabilities/bridge 件引用 core 类（真耦合）。盲循环（剪/拷）震荡证明：
**需引用图工具精确算闭包**（GitNexus 索引 dsha-refactor 已有 42,901 节点——
用它算「vs 链根集的传递闭包」一次性拷齐，不再盲试）。黑名单定稿：
ui/ + 终端件（termux 无源）+ Kotlin 真身优先。

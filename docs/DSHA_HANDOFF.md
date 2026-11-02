# DSHA 重构线 · 会话交接文档（HANDOFF）

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

## 二、真机现状（第 5 个诊断包，dev.26+70 Patch 3）

| 步 | 状态 | 备注 |
|---|---|---|
| 1 Linux 环境 | ✅ | rootfs + 标记 + bash |
| 2 基础工具 | ❌→Patch 4 | Python ✅ 3.12.3；**curl/git** 真因已破：stderr 现形 `E: dpkg was interrupted, run dpkg --configure -a`（前几轮 apt 断流残留）——Patch 4 编排层已加幂等自愈，待真机复验 |
| 3 Node.js | ✅ | v24.16.0 |
| 4 pnpm | ✅ | 10.34.5 |
| 5 dsh | ✅ | **0.2.1-rc.2**（Patch 3 chmod 时序修后点亮） |
| 6 运行补丁 | ✅ | 四条全过（补丁烘在 dsh-runtime.bin 里，解包即成品） |

## 三、下一步（按序）

1. **Patch 4 真机复验**（dpkg 自愈后 apt 装 curl/git）→ 六步全绿即 F1 线点亮收官
2. 补丁链 `applyPatchChain`（四专项：pdf/browser/combo/lan-settings）——
   注意：我们的 dsh-runtime 烘制时已带补丁，**仅升级场景需要**（旧 dsh
   覆盖式升级时现场打补丁），优先级可后置
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

## 七、环境要点

- Flutter `/d/flutter/bin`（export PATH）；Android：`export ANDROID_HOME=D:/AndroidSdk
  ANDROID_SDK_ROOT=D:/AndroidSdk JAVA_HOME="C:/Users/v_qzxgqiu/scoop/apps/temurin17-jdk/current"`
- Dart/Flutter 双绿门槛 + 烟测脚本在 `packages/dsha_core/tool/smoke_*.dart`
- 测试机：红米 K80 Pro（Android 16，24122RKC7C）——诊断包设备
- Sentry：org `comqike` 项目 `my-app`；诊断 issue **MY-APP-3**（dsha-diagnostics）；
  ANR 事件看 MY-APP-2；DSN 在 `tool/sentry.env`（gitignored）
- Shorebird app-id `7a0c80c7-33d1-4c23-9f4a-94686b28ea30`；patch 走 stable 通道

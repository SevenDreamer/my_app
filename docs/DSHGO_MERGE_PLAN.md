# dsh-go 全量融合计划（DSHGO_MERGE_PLAN）

> 状态：v0.1（2026-11-04，待批准）｜工作区：`D:\Projects\my_app`
> 上游：`github.com/ccch1mneyyy/dsh-go`（AGPL-3.0）快照基线 **b4f2d24**（v1.0.10，2026-11-04）
> 索引：GitNexus 已建（69,068 节点 / 166,202 边 / 443 流）——动刀前先查影响面
> **本文取代** `THREE_WAY_COMPARISON.md` / `DSHGO_ARCHITECTURE.md` / `DSHA_HANDOFF.md` 中
> 「只学设计不抄码」「DSHA 线 F2/F3/F4 继续推进」的旧共识（2026-11-04 用户拍板全量融合）。

## 0. 决策记录（用户拍板 2026-11-04，两轮交互）

1. **合规**：直接搬 dsh-go 代码，接受 AGPL 传染——my_app 转 **AGPL-3.0 开源**。
2. **功能范围**：**全部功能**（对话/会话全功能、遥控电脑、插件市场、桌宠、手机操控、论坛）。
3. **DSHA 线冻结**：F2/F3/F4 Dart/Rust 重写计划终止，全面转向 dsh-go 形态。
4. **搬码残骸先收尾**：GitNexus 引用图算 vs 链传递闭包一次性拷齐，编译归零后再开融合。
5. **定位不动**：仍是个人工具箱，DSH 收编为域内子面（功能照做，形态服从工具箱规范）。
6. **底座全量照搬**：含 Kotlin runtime/（RuntimeInstaller/DshProcess/DshService），F1 六步链弃用。
7. **UI/状态管理**：第一阶段照搬不改（Riverpod + 原 UI 并存），后续批次统一 shadcn/MVVM。
8. **美术资产**：明知 ASSETS.md 限制仍直接使用（风险自担，见 §2 留痕与替换预案）。
9. **上游跟进**：快照式 fork，`third-party-refactor` 批次法挑选吸收上游增量。
10. **targetSdk**：照搬 Kotlin runtime，proot 可执行落点改 **nativeLibraryDir**（保高 targetSdk，DSHA 已验证做法，一处小改）。

## 1. 范围边界

**搬入**（app/lib ~29.6 万行 Dart + Kotlin 300 件 + 打包/工具链 ~7.7k 行）：

| 上游 | 内容 | 去向 |
|---|---|---|
| `app/lib/` | 24 个功能子域（chat/market/pets/remote/phone/forum/plugins/runtime/voice/wallpaper/media/update/…）+ `state/` 30+ 状态模块 + l10n | `lib/features/dsh_go/`（镜像上游子目录） |
| `app/android/` Kotlin | runtime/（安装器/进程/前台服务）+ phone/（a11y/background）+ pet/ + 能力插件（files/icons/islands/launch/diagnostics） | `android/` 镜像包结构（改命名空间） |
| `packages/dsh_client` | 纯 Dart 协议层（connection/mux + 20 个 API 模块，18.7k 行） | `packages/dsh_client/` 原名 |
| `packages/dsh_remote` | 远程隧道（remote/relay/ssh，6.2k 行） | `packages/dsh_remote/` 原名 |
| `runtime/` | 运行时打包规格（boot/bridge/direct/lib/locks/media/patches，6.3k 行） | `assets/dshgo_runtime/` 或 tooling 对应位 |
| `tooling/` | build-apk / apk_delta（增量包）/ release_assets | `tool/` |
| `sdk/plugin-kit` + `examples/` | 插件工具包（**MIT**，直接可用） | `packages/plugin_kit/` |

**不搬**（上游的线上基础设施，非 app 功能）：`site/`（官网）、`services/`（share-worker）、
`infra/`（论坛服务端）、`market/`（插件注册表/候选仓库——市场面板 UI 在 app/lib 内照搬）。

## 2. 合规落地

- `LICENSE` → AGPL-3.0；保留 ccch1mneyyy（DSH-TUI）版权头；DSHA（MIT）、proot（GPL-2.0）、
  其余三方声明合并入 `THIRD_PARTY_NOTICES.md`；每批同步更新。
- **仓库转公开**：AGPL 分发义务 = 随附完整源码（GitHub Release + R2 分发热更均适用，
  含 AGPL §13 网络交互条款）。
- 命名空间改造：`io.github.ccch1mneyyy.dsh_app` → my_app 命名空间（批次 1）。
- ⚠️ **美术资产风险留痕（决策 8）**：ASSETS.md 明文「衍生作品再发布请换成自己的名称和素材」，
  版权归 ccch1mneyyy；鲸鱼图含 DeepSeek 官方图标（商标归 DeepSeek）。用户知情选择直接使用。
  **风险**：被权利人要求下架/替换。
  **替换预案**：素材集中于 `app/assets/brand|pets|whale|star/`、mipmap/drawable 图标、
  `brand_glyph.g.dart`——被要求时按此清单整体替换，代码以资源路径引用为主，替换不动代码。

## 3. 批次表

| 批次 | 内容 | 依赖 | 状态 |
|---|---|---|---|
| **0** | **搬码收尾**：GitNexus（dsha-refactor 42,901 节点）算 vs 链根集传递闭包 → 一次性拷齐支撑件 → 编译归零 → 发版解封。⚠️ 过渡投资：此批成果（453 Java）终将随批次 3–7 被 dsh-go 形态替代 | — | ✅ 2026-11-04 编译归零（v1.3.0-dev.41+85 发版）：闭包拷齐 ~57 件 + res 全量合并 + UiMessages 生成物 + flavor 源集（standard/low）补缺 + Kotlin 真身契约补全（@JvmStatic/userStatus/execAuthorizedSms/ensureBound）；ui/ 实为支撑件库（黑名单瓦解为 ui/MainActivity+终端空壳桩），termux/PtySession 终端链维持不搬 |
| **1** | **融合基座**：AGPL 转换（LICENSE/README/NOTICES/仓库公开）+ 快照基线锁定（b4f2d24 + upstream remote + 标签）+ Riverpod 依赖引入 + AGENTS.md 铁律修订（允许双状态管理过渡期）+ 旧共识文档加更正 | 0 | ⬜ |
| **2** | **协议层**：dsh_client + dsh_remote 落位（保无 Flutter 依赖特性）；dsh_api/dsh_chat 接线切换；`packages/dsh_api` 退役 | 1 | ⬜ |
| **3** | **运行时域**：Kotlin runtime/ 全搬 + runtime/ 烘层 + tooling/ 分包链；proot 落点改 nativeLibraryDir（决策 10）；**F1 链退役**（dsha_core install/、rust/dsha_runtime、assets/dsha 277MB 烘层、features/dsha_system） | 1 | ⬜ |
| **4** | **对话域**：chat/commands/composer 全功能（排队/插话/待办/斜杠命令/模型/文件）+ state/ 相关模块 | 2,3 | ⬜ |
| **5** | **插件市场域**：market 面板 + plugins/seams 槽位系统（声明式渲染隔离）+ plugin_kit | 2 | ⬜ |
| **6** | **遥控域**：remote/ + DSH Remote（SSH/隧道）+ share 件；与 device_link/gamepad 的入口边界在此批厘清 | 2,3 | ⬜ |
| **7** | **桌宠/手机操控/论坛域**：pets + phone（a11y/background Kotlin）+ forum + voice/wallpaper/media 体验件（美术按决策 8） | 3 | ⬜ |
| **8** | **统一改造**：Riverpod→ChangeNotifier MVVM、UI→shadcn/DESIGN.md tokens、图标→Lucide、i18n 中文优先收编（可拆多轮） | 4–7 逐域后 | ⬜ |

**每批门槛**：`flutter analyze` + `dart analyze`（packages）双绿 + 真机冒烟 + notices 同步；
发版走 `tool/release.sh` 三件套。
**落位约定**：第一阶段保持上游目录镜像（便于 diff 跟增量），批次 8 再归位四层架构。

## 4. 退役清单（融合完成后移除）

| 资产 | 退役时点 | 备注 |
|---|---|---|
| android/ 453 Java + 5 Kotlin 搬码件 | 批次 3–7 逐域被 Kotlin 真身替代后删 | 批次 0 收尾只为解发版封锁 |
| packages/dsha_core（54 dart） | 批次 3 后 | 备份 E1/插件 E2 件被 dsh-go 形态替代 |
| rust/dsha_runtime + jniLibs 六件 | 批次 3 后 | Rust 解包线随 F1 链退役 |
| assets/dsha/（277MB 烘层） | 批次 3 后 | 换 dsh-go runtime/ 烘层（abi 分包减重） |
| features/dsha_system | 批次 3 后 | 换 dsh-go 运行时安装形态 |
| features/vscreen | 批次 7 后 | 由 dsh-go phone 域（手机操控）替代 |
| packages/dsh_api（11 dart） | 批次 2 后 | 由 dsh_client 替代 |
| docs/DSHA_REFACTOR_PLAN.md F2/F3/F4 行 | 批次 1 | 标注终止，指向本文 |

**保留不动**：`app/update/`（R2+Shorebird）、Sentry 诊断、`lib/design/` 体系、
工具箱其他域（notes/robot_eyes/live2d/gamepad/device_link/component_gallery/hermes）。

## 5. 取舍与后果（如实记录）

- **沉没成本**：F1 六步真机全绿链、E 批七件套/备份、D 批 vscreen 重写随决策 3/6 退役。
  理由：与其长期维护两条实现哲学（DSHA 契约保真 vs dsh-go 体验优先），不如统一到 dsh-go 形态。
- **批次 0 是过渡投资**：只为解开发版封锁（编译长尾卡发版），成果终将退役——勿在此批追加深度。
- **targetSdk 差异**：与上游有一处结构差异（nativeLibraryDir vs targetSdk=28），跟增量时该文件必冲突，固定按决策 10 解。
- **双状态管理并存期**：Riverpod + ChangeNotifier 到批次 8 收敛；AGENTS.md 铁律在批次 1 修订为"过渡期豁免"。
- **AGPL 现实义务**：仓库公开、源码随附、§13 覆盖 R2 分发；Shorebird 热更产物同样在义务内。
- **规模事实**：搬入 ~31 万行（现 my_app ~7 万行的 4 倍余）——融合后 my_app 主体即 dsh-go 移植，工具箱其他域为辅（定位虽仍为工具箱，代码体量 DSH 域占大头）。

## 6. 风险

| 风险 | 缓解 |
|---|---|
| 上游周更（1.0.10，活跃） | 镜像落位 + third-party-refactor 批次法挑选吸收；冲突热点（targetSdk 文件）预案固定 |
| 美术资产被追责（决策 8） | §2 替换预案（素材集中、替换不动代码）；不主动放大品牌露出 |
| dsh-go 年轻（2026-10-25 创建），成熟度未知 | 搬入即继承其 bug 面；真机冒烟每批必做；上游 issue 跟踪 |
| 桌面端 DSH 域缺位（dsh-go 仅 Android，minSdk 26） | registry 平台声明如实标注；桌面 DSH 体验退回收敛（管理/控制类），批次 4 设计时细化 |
| 发版链合流（tooling abi 分包 × R2/Shorebird） | 批次 3 内合流设计，tool/release.sh 改造 |
| 双 UI/双状态并存期认知负担 | 批次 8 明确收敛时点；并存期代码集中 features/dsh_go/ 不外溢 |

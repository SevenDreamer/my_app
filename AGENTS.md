# my_app — Agent 协作规则

> 定位：个人工具箱 App（Flutter，移动优先、桌面互补）。
> 愿景见 `docs/VISION.md` · 视觉规范 `DESIGN.md` · 计划 `docs/ROADMAP.md` · 踩坑档案 `docs/PITFALLS.md`。
> 首次接触先读这四份，再动代码。

## 架构铁律（lib/ 四层）

```
app/      应用外壳：底部导航壳、三个 tab、功能注册表
features/ 真·功能：每域一目录（device_link / notes / robot_eyes）
data/     数据层：models + services（按类型分组）
design/   设计层：tokens / theme / widgets（即官方 ui/core）
```

- **判断规则：不是给用户点开用的"能力"，就不进 `features/`。**（tab、壳、注册表属于 `app/`）
- **MVVM**：View 用 `ListenableBuilder` 读 ViewModel 快照 + 调命令方法，
  **禁止 View 直连数据服务**（参照 `features/notes/notes_view_model.dart` 的形态）。
  ViewModel 继承 `ChangeNotifier`，数据服务经构造函数注入。
- **新功能必须登记**：`app/feature_registry.dart` 的 `FeatureEntry`，
  必须带平台能力声明（`desktop`/`mobile`：`full|limited|none`）——
  禁止"点进去才发现该平台不能用"（VISION 的硬规矩）。
- robot_eyes 域保持内聚：expressions（语义）、eyes（渲染样式层）、inputs（输入源）、
  widgets、page 全部留在 `features/robot_eyes/` 内；对风格/输入的抽象
  （EyeRenderer、LookSource）不外溢到其他层。

## 视觉与组件

- **`DESIGN.md` 是视觉唯一来源**：颜色/字号/圆角/间距只允许从 `lib/design/tokens.dart` 取；
  改视觉 = 先改 DESIGN.md 再同步 tokens。**页面禁止硬编码颜色值。**
- 组件层 = `shadcn_ui`（ShadButton / ShadCard / ShadInput / ShadTextarea / ShadIconButton…）；
  shadcn 没有的壳（`AppAppBar` / `AppListTile` / `AppSection`）在 `lib/design/widgets/`，同样只吃 tokens。
- **图标一律 `LucideIcons.*`**，不新增 Material Icons 引用（历史原因见 PITFALLS #1）；
  入口类图标包进 icon-block（primary 淡底）。
- 主题唯一入口 `AppTheme`：`shadLight`（ShadZincColorScheme + tokens 覆盖）
  → `materialize`（Material 组件覆盖层）。不要在页面里自建 ThemeData。

## 编码约定

- 注释：模块级 `//!`、文档 `///`、行内 `//`，中文。
- Widget 构造：named + const（Flutter 惯例）。**暂不使用 Dart primary constructors**
  ——语言版本门槛未达成（pubspec `>=3.3`、`.fvmrc` Dart 3.11 < 3.13），见 ROADMAP 想法池。
- 路由：命令式 `Navigator.push`；出现 deep-link/URL 需求前不上 go_router
  （官方技能 `flutter-setup-declarative-routing` 的适用范围本就不含我们）。
- import 分组：dart → package → 相对路径，相对路径用 `../` 层级表达。

## 验证门槛（每次改动收尾必须双绿）

```bash
export PATH="/d/flutter/bin:$PATH"     # bash 内 flutter 用 POSIX 路径
flutter analyze                          # 必须 No issues found
npx -y -p @google/design.md designmd lint DESIGN.md   # DESIGN.md 变更时：0 errors / 0 warnings
```

## 版本与发布

- **版本单一来源 = `pubspec.yaml` 的 `version: X.Y.Z+N`**（semver：
  MAJOR 破结构 / MINOR 新功能 / PATCH 修 bug；`+N` 每次发布自增）。
- **发布三件套必须同号**：pubspec bump → `git tag vX.Y.Z` → GitHub Release
  （附构建产物）；历史 `dev-v3` 式标签不再使用。
- CHANGELOG 由 `git log v旧..v新 --oneline` 生成（commit 已遵循 feat:/fix:/refactor:）。
- **发布通道**：正式版=普通 Release；测试版=GitHub **prerelease** + tag 带预发布段
  （`vX.Y.Z-dev.N`，pubspec `version: X.Y.Z-dev.N+M`）。`releases/latest` 天然只出
  正式版；app 内「更新通道」（稳定/开发）决定收哪个通道的推送。
  预发布排序规则：`1.2.0 < 1.3.0-dev.1 < 1.3.0`。
- 更新与分发（v2）：**大版本走 Cloudflare R2 manifest 免授权分发**——
  `manifest.json` 与安装包托管在 R2 公开桶（过渡期同内容双写
  `manifest-dev.json` 兼容老版本按通道读取，老版本退场后删），
  app 匿名 GET 检查更新 + 下载安装（`lib/app/update/`，源抽象 `UpdateSource`）；
  iOS 明确不支持自动更新。发版本地一键：`tool/release.sh ["更新说明"]`
  （Shorebird release → S3 直传 R2 → 刷 manifest，上传 curl aws-sigv4 直连；
  需 S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY / R2_BASE_URL）。
- GitHub 流水线件（CiNotifier 通知 / Device Flow 授权 / dev-release.yml）
  已于 2026-10-25 整体移除——更新分发完全走 R2，二进制内无任何 token。

### 热更（Shorebird patch）

- 热更 = **Shorebird patch，只替换 Dart 代码**；原生代码 / assets / Manifest /
  插件原生部分改动**必须走新 release + 重装**，patch 带不动。
- Shorebird 以 `version+build` 唯一注册 release（`shorebird release`）；
  patch 挂在 release 下（Patch 1、2、3…）**不占版本号**。
  **设备只收自己 `version+build` 的 patch，不跨 release**：
  发了新 release 后老设备不会自动升级，仍走 GitHub Release 重装。
- 因此两条硬规矩：`+N` 每次 `shorebird release` 前必须自增（重发也算，否则撞
  "release already exists"）；`shorebird patch` 构建时 pubspec 版本必须与
  目标 release 同号（`--release-version=X.Y.Z+N` 显式指定）。
- 本地 CLI 一律走仓库包装脚本 **`tool/shorebird.sh`**（已内置构建环境变量，
  并绕过官方 shim 的 MSYS 路径 bug）：
  ```bash
  tool/shorebird.sh release android --artifact=apk          # 注册新 release（先 bump +N）
  tool/shorebird.sh patch android --release-version=X.Y.Z+N  # 发热更 patch
  tool/shorebird.sh releases list --app-id <app_id>
  tool/shorebird.sh patches list --app-id <id> --release-version <ver>
  ```
  直接调 `~/.shorebird/bin/shorebird` 会因 shim 把 MSYS 路径喂给原生 dart 而报错；
  构建类命令缺 `ANDROID_HOME`/`JAVA_HOME` 时报 "No Android SDK found"（脚本均已兜底）。
  引擎版本由 CLI 锁定（当前 Flutter 3.47.7，与 dev-release.yml 的
  `flutter-version` 一致，改一边必须同步另一边）。

## Rust 侧（桌宠 workspace）

- `rust/` 是 Cargo workspace（`pet` 为成员）；将来网络扫描 sidecar 等同放此处。
- 构建**必须 nightly**：`cargo +nightly build`（stable 编不了 gpui，PITFALLS #11）。
- gpui/gpui_platform 锁 Y 项目同 rev（zed `b1a7ef0`）以复用本机缓存；
  gpui API 坑位先查 `docs/PITFALLS.md` 四节 + `gpui-desktop-app` skill。
- 桌宠架构与路线见 `docs/RUST_PET.md`；FFI 一律零依赖手写 `extern "system"` 声明。

## 环境要点

- 工具链：本机 `D:\flutter` **3.47.7**（Dart 3.13.5）；`.fvmrc` 锁 **3.41.9**（Dart 3.11）。
  语言特性的可用性按 **pubspec sdk 下限与 .fvmrc 两者中较低者** 判断。
- `windows/` 下的 C++ **禁写中文注释**（MSVC GBK 编码 → 警告即错误，见 PITFALLS #2）。
- 热重载 `r` 只用于小改；**新增文件 / 改类结构 / 涉及 late 字段 → 一律大 `R` 热重启**。
- Android 相关环境变量：只设 `ANDROID_HOME`，**不要设 `ANDROID_SDK_HOME`**（见 PITFALLS #5）。

## AI 协作规则

- 项目技能在 `.agents/skills/`（官方 flutter/dart 23 个 + shadcn + sqflite）；写对应领域代码前先读技能。
- MCP：`dart mcp-server`（Hermes 已配 14 工具）+ 项目级 `.agents/mcp_config.json`。
- **外部包名 / CLI 命令必须先验证再写进配置**（`npm view <pkg>` 或查官方文档），
  禁止凭印象编造（本项目已发生过一次 MCP 包名 404）。
- 大改动遵循：先分析现状 → 给方案与取舍 → 确认后动手；每步收尾跑验证门槛。

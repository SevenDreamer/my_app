# 踩坑档案（PITFALLS）

> 只记录**本项目真实遇到过、已解决**的问题。格式：现象 → 根因 → 解法（含出处）。
> 新增条目按发生顺序追加到对应分区。

## 一、Flutter 3.47 / Windows 桌面

### 1. 图标全部渲染成方框（tofu）
- **现象**：Material Icons 显示为 □，文字正常；冷启动 exe 也复现（排除热重载）。
- **根因**：Flutter 3.47 起 Windows/Linux/macOS **默认启用 Impeller**，其 SDF 字体
  渲染处理不了图标字形。
- **解法**：`windows/runner/main.cpp` 在 `DartProject` 创建后加：
  ```cpp
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
  ```
  回退 Skia（官方退出通道，出处 [flutter/flutter#191860](https://github.com/flutter/flutter/issues/191860)）。
  **注意**：Skia 回退是官方声明的暂时方案，升级 Flutter 后需复查此问题；
  新代码图标改用 Lucide（AGENTS.md 规则）可连根规避。

### 2. Windows runner 一写中文注释就构建失败
- **现象**：`C4819`（无法在代码页 936 表示）→ 项目"警告即错误"升级为 `C2220`，链接失败。
- **根因**：MSVC 按系统 GBK 读 UTF-8 无 BOM 文件。
- **解法**：`windows/` 下 C++ 文件注释一律英文。

### 3. 热重载后 `LateInitializationError`
- **现象**：改完代码按 `r`，报 `_fromType has not been initialized`。
- **根因**：热重载保留旧 State 实例，新增的 `late` 字段从未被赋值。
- **解法**：字段声明期给默认值（免疫热重载）；**结构性改动（新增文件/类）用大 `R`**。

## 二、Android SDK / 模拟器（本机踩过）

### 4. `flutter run` 找不到模拟器 / `adb devices` 间歇丢设备
- **现象**：`No supported devices found`，但同刻 `adb devices` 有时显示正常；
  `emulator -list-avds` 也间歇输出空；DDS 热重载服务连 `127.0.0.1` 被拒。
- **根因**：本地回环连接受干扰（复现场景下系统装有 QQ 电脑管家实时防护、iTFS）；
  设备注册状态抖动（10 次采样 5~8 命中）。**未最终定论**，标注为嫌疑。
- **解法**：`flutter devices` 刷到设备后立刻 `flutter run`；不行则冷重启模拟器；
  根治需排查安全软件对 `adb.exe`/`qemu` 的拦截或加白名单。

### 5. 设了 `ANDROID_SDK_HOME` 后 `emulator -list-avds` 永远为空
- **现象**：AVD 文件齐全但列表空；删变量立即恢复。
- **根因**：该变量语义**不是** SDK 路径（历史包袱），会改变 emulator 的 AVD 查找位置。
- **解法**：永远不设它，只用 `ANDROID_HOME`；AVD 用默认 `$HOME/.android/avd`。

### 6. Flutter 报 `Android sdkmanager not found`（SDK 明明装了）
- **根因**：目录结构要求 `cmdline-tools/latest/bin`，缺 `latest` 层 Flutter 认不到。
- **解法**：保持 `D:\AndroidSdk\cmdline-tools\latest\bin\sdkmanager.bat` 结构。

### 7. MSYS 下 `cmd //c <bat>` 假死
- **现象**：`yes | cmd //c sdkmanager.bat` 无输出卡死，`yes` 的 y 灌进 cmd 交互提示。
- **根因**：反斜杠参数被 MSYS 路径转换破坏。
- **解法**：直接执行 `.bat`（不套 `cmd //c`）；`flutter` 等工具在 bash 内用
  POSIX 路径（`/d/flutter/bin`），`D:/flutter/bin` 形式 PATH 查找会失效。

### 8. 笔记功能在桌面端一点就炸
- **现象**：`MissingPluginException`（sqflite）。
- **根因**：sqflite 仅支持移动端，Windows 无绑定。
- **解法**：`feature_registry.dart` 标 `desktop: PlatformSupport.none`（入口自动隐藏）；
  未来桌面放开需换 `sqflite_common_ffi`。

## 三、配置与工具

### 9. pubspec.yaml 出现重复顶层 `flutter:` 段
- **现象**：往 dependencies 插入新块时误写了独立的 `flutter:` 顶层段。
- **解法**：`grep -c '^flutter:' pubspec.yaml` 必须为 1；`flutter_localizations` 属于
  dependencies（`sdk: flutter`），不是顶层段。

### 10. AI 编造 MCP 包名（404）
- **现象**：配置里写了 `@flutter/dev-knowledge-mcp`——npm 404（包不存在）。
- **根因**：凭印象写包名，未验证。
- **解法**：外部包/命令先 `npm view` 或查官方文档验证再入配置（已入 AGENTS.md 规则）。

## 四、Rust / GPUI（桌宠侧）

### 11. stable Rust 编不了 gpui：`use of unstable library feature cold_path`
- **现象**：`cargo build`（stable 1.94.1）编译 zed 的 gpui 报 E0658——
  `profiler.rs` 调 `std::hint::cold_path`（issue #136873，未稳定）。
- **解法**：**用 nightly 构建**：`cargo +nightly build`（本机已装
  `nightly-x86_64-pc-windows-msvc`，gpui/zed 生态的实际要求）。
- **配套**：`rust/pet` 依赖锁 Y 项目同 rev（zed `b1a7ef0` / gpui 0.2.2）
  复用 git 缓存；注意 `CARGO_HOME` 在 scoop 的 rustup 下
  （`C:\Users\<u>\scoop\persist\rustup\.cargo`），不是 `~/.cargo`。

### 12. gpui 小语义（P0 实测结论）
- `div` 不在 prelude 里（需 `use gpui::div;`）；`full_size()` 不存在 →
  改用 `w_full().h_full()`。
- `WindowKind::PopUp` 在 Windows 实测：**置顶 ✓ + 不进任务栏 ✓ +
  无标题栏（appears_transparent）✓**——桌宠窗口形态零 FFI 达成。

### 13. gpui 实体/异步语义（P1 实测结论）
- **async 闭包的第二参本来就是 `&mut AsyncApp`**：`cx.spawn(async move |this, cx| {...})`，
  内部 `this.update(cx, ...)` **直接传 cx**——写 `&mut cx` 变成引用的引用
  （报 `&mut AsyncApp: AppContext` 不满足）。
- `cx.open_window(..., |window, cx| cx.new(|cx| View::new(window, cx)))`：
  外层构建闭包拿 (window, cx)，**内层 `cx.new` 的闭包只吃 1 参**。
- `WeakEntity::update` 签名：`update<R, C: AppContext>(cx: &mut C, f: FnOnce(&mut T, &mut Context<T>))`
  （entity_map.rs；update_in 多带 &mut Window）。
- 帧循环标准式：`cx.spawn(async move |this, cx| { loop { cx.background_executor()
  .timer(Duration::from_millis(16)).await; this.update(cx, |t, cx| { t.tick(..); cx.notify(); })..}}).detach();`
  ——update 返回 `Result`，实体销毁后靠 `.unwrap_or(false)` 退出循环。
- 画布：`canvas(prepaint, paint)` 两段闭包均 `'static`（状态需克隆进闭包）；
  画矩形 = `window.paint_quad(fill(bounds, color))`；`Pixels` 间的算术结果仍是 `Pixels`
  （再包 `px()` 即 E0308）。

### 14. Kotlin 增量编译缓存撞注册（Android release 构建）
- **现象**：`flutter build apk --release` 卡在 `:package_info_plus:compileReleaseKotlin`，
  报 `Could not close incremental caches … Storage for … is already registered`
  （url_launcher_android 同步失败；`flutter clean` 后依然复现）。
- **根因**：Kotlin 增量编译在多插件模块并发编译时共享缓存注册冲突（daemon 状态污染类问题）。
- **解法**：`android/gradle.properties` 追加 `kotlin.incremental=false` +
  `org.gradle.parallel=false`——禁增量/并行保构建稳定（插件模块小，代价可忽略）。

### 15. 私有仓库 Release 资产的扫码分发
- **现象**：手机浏览器直接打开 `releases/download/...` 的资产 URL **404**（登录墙）。
- **解法**：桌面端用 Device Flow token 调资产 API（`Accept: application/octet-stream`，
  `followRedirects=false`）取 **302 的 Location**（Azure 签名 URL）。
- **有效期实测 1 小时**（`se`/`skt` 窗口）——二维码放这个短时 URL，
  弹窗文案提示"过期重新打开弹窗"即可。

### 16. Android 签名配置在 CI 上炸（null cannot be cast to String）
- **现象**：本地构建好好的，GitHub Actions 上 `build.gradle.kts:44` 报
  `null cannot be cast to non-null type kotlin.String`。
- **根因**：`key.properties` 被 gitignore（正确），CI 上不存在——
  `keystoreProperties[...] as String` 读 null 直接炸。
- **解法**：① gradle 判断 `key.properties` 存在才建 release 签名（缺失降级 debug 并警告）；
  ② CI 经 **GitHub Secrets**（ANDROID_KEYSTORE_B64/PASSWORD/ALIAS）恢复签名文件——
  Secrets 是加密存储，与"密钥不入库"原则不冲突。
- **附坑**：CI 写 key.properties 别用 heredoc（缩进会进文件）→ 用 `printf`；
  `storeFile` 相对 **app 模块目录**写 `my_app-release.jks`（不是 `android/app/...`）。

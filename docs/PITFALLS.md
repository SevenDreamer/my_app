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

### 17. release 包没有 INTERNET 权限（E1001 假象）
- **现象**：release 包所有网络操作失败（更新检查/授权），报 `E1001`
  `Failed host lookup: "github.com"`——但手机浏览器能打开同一地址。
- **根因**：Flutter 模板**只在 `debug`/`profile` manifest 声明 INTERNET**，
  `main` manifest（release 打包合并源）没有——release 包全断网，
  无权限在 getaddrinfo 层表现为 DNS 解析失败（E1001 假象）。
- **解法**：`android/app/src/main/AndroidManifest.xml` 显式加
  `<uses-permission android:name="android.permission.INTERNET"/>`。
- **鉴别要点**：浏览器能开、app 报 DNS 错 → 先查 INTERNET 权限，再查网络。

### 18. build.gradle.kts 的 ndkVersion 声明 = CI 强制下载 1GB NDK
- **现象**：无 native 代码的项目，CI 每次构建都在下载/解压 NDK 28（几百 MB 到 1GB），
  缓存了也没明显提速（大包 save/restore 本身就慢）。
- **根因**：Flutter 模板默认写 `ndkVersion = flutter.ndkVersion`——声明即触发
  AGP 自动安装对应 NDK，哪怕全项目插件都是 Java/Kotlin。
- **解法**：删掉 `ndkVersion` 声明（本项目 sqflite/webview/url_launcher 等全为
  Java/Kotlin，无 native 需求）；真要用 NDK 的项目反而应该显式锁版本。
- **附注**：CI 缓存 key 不要混入 `pubspec.yaml`（版本号 bump 会让 SDK 缓存失效），
  只跟 `android/` 构建配置的 hash 走。

### 19. CI 缓存 key hash 配置文件 = "一改配置就砸缓存"的恶性循环
- **现象**：明明配了 actions/cache、缓存也成功保存（`gh cache list` 可见），但每次
  构建仍全量下载 SDK/NDK。
- **根因**：key 里 hash 了 `gradle.properties`/`build.gradle.kts` 这类**会被频繁
  调优的文件**——每改一次 key 就变，缓存 miss → 重新下载 → 存新缓存 → 下次
  调优又 miss……调优越勤，缓存越废。
- **解法**：工具链缓存（SDK/NDK/Gradle）的 key 用**手工版本号**（`...-cache-v1`），
  确实需要失效时手动改 v2；别用源码/配置文件的 hash。
- **附注**：`flutter build apk` 会主动安装 NDK（flutter_tools 的 installNdkVersion，
  即使无 native 代码、即使删了项目里的 ndkVersion 声明、即使禁了
  android.builder.sdkDownload）——NDK 基本是 Flutter Android 构建的硬需求，
  接受它并缓存它，比对抗它省时间。判断缓存是否命中看日志的 `Cache mode`：
  `write`=miss（存），`restore`/`= read-write`=hit。

### 20. NDK 版本不是你能选的：:jni 模块钉死 Flutter 默认版本
- **现象**：想用 CI 镜像预装的 NDK 30.0（零下载）替换 Flutter 默认的 28.2，
  无论在 :app 还是全局 gradle 覆盖 ndkVersion，构建都报
  `A problem occurred configuring project ':jni' > NDK not configured.
  Preferred NDK version is '28.2.13676358'`。
- **根因**：插件的原生模块（如 path_provider_android 的 :jni）按**Flutter
  的默认 NDK 版本**（flutter.ndkVersion）查 NDK，不受 app 层 ndkVersion
  影响；subprojects 级 afterEvaluate 覆盖又会撞 "project already evaluated"。
- **解法**：认了 28.2——workflow 里显式 `sdkmanager install "ndk;28.2.13676358"`
  + 仓库缓存兜底（首次下载一次，之后缓存命中）。
- **附注**：另一个翻车点——gradle.properties 的 `org.gradle.configuration-cache=true`
  与 Flutter 的 `ReleaseMinSdkCheck` 任务不兼容（不可序列化对象），会直接
  构建失败；只开 `org.gradle.caching=true`（build cache）是安全的，且收益大
  （本地实测 141s → 3s）。

### 21. :jni/NDK 连环坑的根治：钉 path_provider_android = 2.2.23
- **终局方案**：`dependency_overrides: path_provider_android: 2.2.23`（pub.dev
  实测的版本分界：2.3.0 起引入 jni，2.2.23 是最后一个纯 Kotlin 版）。
- **效果**：`:jni` 模块从依赖树消失（pubspec.lock 中 jni 零命中），
  NDK/CMake 完全退出构建链——workflow 删掉安装步骤，缓存瘦身，
  CI 不再有任何 1GB 级工具链下载。
- **何时解除钉死**：上游 path_provider_android 去掉 jni 依赖（或我们不再用
  path_provider）后移除 dependency_overrides。

### 22. NDK 强制下载的真正元凶：flutter_tools 的"已装版本清单"检查
- **现象**：:jni 根治后（#21），CI 仍每次下载 1GB 的 NDK 28.2。
- **根因**：`flutter build` 把"已安装 NDK 版本列表"作为 gradle 属性传入
  （flutter_tools 的 gradle.dart：`-P...InstalledNdkVersions=<已装清单>`）；
  清单里没有 flutter.ndkVersion（28.2）就触发安装——此前所有"禁下载"
  尝试（删 ndkVersion 声明 / android.builder.sdkDownload=false）都治不到它。
- **失败的尝试（诚实记录）**：造幻影 NDK 目录（只有 source.properties）骗过
  清单检查——立刻穿帮：AGP 的 `stripReleaseDebugSymbols` 任务要用 NDK 的
  `llvm-strip` 剥离 Flutter engine .so 的调试符号，**即使项目无 native 代码，
  engine 的 .so 也要 strip**——NDK 是真需求，骗不过要真干活的工具。
- **终态解法**：认了 NDK——显式 `sdkmanager install "ndk;28.2.13676358"` +
  仓库缓存兜底（首次下载一次，之后 Cache hit）。**真正去掉它的唯一路**：
  不用 path_provider（或换无 jni 实现）+ packaging doNotStrip（接受 APK 变大）。
- **附注**：CMake 可以真正退场（:jni 根治后无 native 编译），只有 NDK 留守。

### 23. NDK 优化全案回退（2026-10-21 决定）：不折腾就是最优解
- **背景**：为消除 NDK 每次下载，先后尝试删 ndkVersion 声明 / 禁 AGP 自动下载 /
  双 NDK 矩阵 / 钉 path_provider_android / 幻影 NDK 目录 / 显式安装+环境变量
  覆盖——共 7 轮 commit（e748478→c39b75f），每一层都冒出新的拦截者。
- **决定**：全部回退，NDK 恢复 `flutter.ndkVersion` 模板原样 + flutter build
  全自动下载。**接受每次下载的慢，换构建的稳定**——NDK 的自动化本来就是
  Flutter 工具链设计好的路径，对抗它的成本已超过收益。
- **保留的改进**（与 NDK 无关）：四节点并行、Gradle build cache、签名 secrets
  校验、分架构包、失败 Issue 通知、actions 版本升级。
- **仍然有效的经验**：#18/#19/#20/#22 的排查方法论（Cache mode 诊断、flutter_tools
  的清单机制、:jni 的版本钉死）——下次 Flutter 升级若 NDK 行为变化，从这里查起。

### 24. Python 文本替换（str.replace）静默失败——必须断言校验
- **现象**：批量改文件时 `s.replace(old, new)` 找不到锚文本**不报错、返回原串**，
  改动"看起来做了"其实没生效——一天内踩了 4 次（签名 secrets 名、feature
  注册块、pubspec 资产段、NDK 版本行），每次都要等下游报错才暴露。
- **解法**：替换后立即断言标志物（如 `assert '关键字' in s` 或比对新旧差异），
  或改用 patch 工具（有 diff 反馈）。**批量脚本改文件 = 校验是义务不是可选**。

## 五、Live2D / WebView（Android 渲染侧）

### 25. WebView 加载本地资源报 ERR_CLEARTEXT_NOT_PERMITTED
- **现象**：`live2d` 包（WebView + WebGL）在 Android 上加载模型失败，JS 控制台
  报 `ERR_CLEARTEXT_NOT_PERMITTED`；iOS/桌面正常。
- **根因**：WebView 走 Flutter dev server / 本地 HTTP 服务取 assets
  （`http://127.0.0.1:<port>/...`）是**明文 HTTP**，Android 9+（API 28）默认
  禁止 cleartext，WebView 直接拦掉——与 INTERNET 权限（#17）是两道独立关卡。
- **解法**：`android/app/src/main/res/xml/network_security_config.xml` 只放行
  `127.0.0.1`/`localhost`（**不开全局明文**），Manifest 挂
  `android:networkSecurityConfig`。
- **出处**：官方文档 "Android 9.0 behavior changes — Cleartext traffic"。

### 26. 部分 Live2D 模型报 Unknown error：moc3 v5/v6 格式与 Core 版本不匹配
- **现象**：同一页加载 Mao/IceGirl 正常，唯独 Ren 报 `Unknown error`（包内部
  catch 掉了真实错误，只吐这一句）。
- **根因**：模型的 `.moc3` 由 Cubism Editor 5.3 导出 = **v6 格式**，而包默认
  打包的 Cubism Core 只认 v5——格式不匹配，且错误被包吞掉后只剩 "Unknown error"。
- **解法**：换官方**版本化分发**的 Core：`sdk-web/core/06/`（Cubism 5.3 Core），
  与包解耦、按模型格式选版本。
- **鉴别要点**：同页多模型只有一个挂 → 优先怀疑该模型的导出版本，而不是代码；
  排查手段用日志流（APPLOG/JS 控制台）而不是截图问人。

### 27. Core 6 白屏：渲染库读已被移除的 `drawables.renderOrders`
- **现象**：模型一路「加载完成」，但画布**全白**，看不到任何东西；JS 控制台每帧刷
  `Uncaught TypeError: Cannot read properties of undefined (reading '0')`
  （`pixi-live2d-display@0.4.0` 的 `CubismRenderer_WebGL.doDrawModel`）。
- **根因**：`#26` 为支持 Ren（moc3 v6）切到 Core 6.0.1 后，Core 6 **把
  `drawables.renderOrders` 移除了**（改挂到 `Model.renderOrders`，含
  drawable + offscreen 两段）。渲染库仍读旧字段 → `undefined`，取 `[0]` 即抛，
  整帧绘制中断。全量比对确认：渲染库依赖的 15 个 `drawables.*` 字段里**只有这一个**
  在 Core 6 缺失，其余 14 个都在——所以补这一个就够，不会连锁崩。
- **解法**：vendor 一份打过补丁的 Core 到 `assets/live2d/live2dcubismcore.min.js`，
  在 Core 定义之后包住唯一的模型创建入口 `Live2DCubismCore.Model.fromMoc`，
  建好模型后把 `drawables.renderOrders` 指回 `Model.renderOrders` 的前
  `drawables.count` 个（裁掉 offscreen 段，语义与 Core 5 完全一致）。
  页面改用本地 `cubismCoreJsUrl` 指向它。补丁幂等、Core 5 下不覆盖原生字段。
- **⚠️ 附坑（走了两小时弯路）**：包内 HttpServer 的路由是
  `/assets/<path>` → 剥一层前缀 → `rootBundle.load(<path>)`，而 Flutter 资产 key
  **本身要带 `assets/`**。所以喂给 `cubismCoreJsUrl` 的是**双层**
  `assets/assets/live2d/xxx.js`（与模型 URL 同构：`/assets/assets/models/…`）。
  写成单层 → 404 → 404 响应体是 `text/plain` → 浏览器报
  `Refused to execute script ... MIME type not executable`，表象完全不像「路径写错」，
  实际上是它。
- **参考**：上游同款问题 [guansss/pixi-live2d-display#177](https://github.com/guansss/pixi-live2d-display/issues/177)、
  [untitled-pixi-live2d-engine#11](https://github.com/Untitled-Story/untitled-pixi-live2d-engine/issues/11)
  （后者给出的结论是「换回 Core 5.1」——即放弃 v6 模型；我们选择补字段以兼容两者）。

### 27. patch 会被「图标字体资产差异」拦住：lucide.ttf 按字形裁剪

- **现象**：`shorebird patch` 构建通过后报
  "Your app contains asset changes ... lucide.ttf"，直接 "Not publishing"。
- **根因**：Flutter 把 lucide.ttf **按用到的字形裁剪**进资产——增删任何
  `LucideIcons.*` 引用都会改变字体资产哈希；而 patch 只带 Dart 代码、不带资产。
- **解法**（按优先级）：
  - patch 里只用 release 基线**已有**的字形（`grep -rho "LucideIcons\.\w*" lib/`
    对照当次 release 时的集合），字形集合一致 → 资产逐字节相同 → 干净通过；
  - `--allow-asset-diffs` 强发——但新字形在旧字体里不存在，**新图标会渲染成方框**；
  - 涉及图标增删的改动直接 bump 版本走 `tool/release.sh`（与用户的约定）。
- **实测补充**（2026-10-23）：即使**图标一个没动**，patch 也可能被拦——对比
  dev.6 与 dev.7 构建的 lucide.ttf，码点 32 vs 33，dev.7 多出一个 `0xe1b4`
  （不是任何 LucideIcons 常量，包源码里查无此码点）。即图标字体的裁剪产物
  在构建间存在微小抖动（apk/aab 构建目标、构建缓存皆可疑）。结论修正：
  「字形集合一致」只是提高通过率，**不是保证**；被拦就是升版，别恋战。

### 28. 纯 widgets 页面「黄下划线/红字」：MaterialApp _errorTextStyle 泄漏

- **现象**：脱离 Material 的页面（如「关于」页）文字下有黄色双下划线，
  字体像等宽（monospace），未设颜色的 Text 还会发红——像是"缺默认字体"。
- **根因**：`MaterialApp` 故意把 `WidgetsApp.textStyle` 设成丑陋的
  `_errorTextStyle`（红字 + 黄色双下划线 + monospace，见 material/app.dart），
  用来提示"文字没被 Material 覆盖"。纯 widgets 页面壳（AppScaffold 等）
  若不提供 `DefaultTextStyle`，子级样式 merge 时这些属性就漏进来。
- **解法**：页面壳用 `DefaultTextStyle(style: AppTypography.bodyMd, ...)`
  建文字基线（见 `lib/design/widgets/app_scaffold.dart`）——任何去 Material
  的自建页面壳都要带这一层。

### 29. 启动门死循环：patch 下载完紧跟 `Runtime.exit(0)` 会让 patch 永不生效

- **现象**：dev.10 上「热更加载页」无限重启循环，patch 每轮都重新下载、永不生效。
- **根因**（两个叠加）：
  1. `update()` 下载完 patch 立即原生 `Runtime.exit(0)` 重启——硬杀进程会截断
     patch 的落盘/生效确认，引擎判定启动失败回滚，下一轮又见 outdated 又下载；
  2. 回环护栏的时间戳存 FlutterSecureStorage（异步落盘），写完紧跟 `exit(0)`
     同样被截断——护栏永远读到旧值，形同虚设。
- **旁证**：dev.9（基线包无启动门，patch 全靠自然重启生效）一切正常。
- **解法**（三底线）：
  1. 下载完**不杀进程**，提示"重启后生效"直接放行，下次自然启动生效；
  2. 重启尝试护栏改**普通文件 + `flush: true`**（立即落盘，扛硬杀），
     同一 patch 最多重启 2 次；
  3. 任何分支最终 `_finish()` 放行，「跳过」按钮全程可见。
- **通用教训**：`Runtime.exit(0)` 硬杀进程前，所有异步落盘的写入都可能丢失；
  需要跨重启存活的状态必须同步 flush 到普通文件，不能用异步 KV 存储。

### 30. WindowsApps 的 python3 是商店 stub：静默退出 49 杀脚本

- **现象**：bash 脚本（`set -e`）跑到调 `python3` 的那行**无声死亡**，退出码 49，
  没有任何报错输出（发版脚本连续两次死在这）。
- **根因**：`C:\...\Microsoft\WindowsApps\python3.exe` 是微软商店的占位 stub
  （`command -v` 找得到它），一运行就静默退出 49；真正的解释器是 `python`。
  "取第一个存在的"探测（`command -v python3 || command -v python`）会被 stub 骗过。
- **解法**：解释器探测必须**试跑验证**——`"$c" --version >/dev/null 2>&1` 通过才
  采纳（见 `tool/release.sh` 的 PY 探测）；Windows 上任何"找可执行文件"的
  选择逻辑都该加这层验活。

### 31. WSL System32 的 bash.exe 吞引号：`"$code"` 被 argv 翻译吃掉

- **现象**：Dart `Process.start('bash', ['-c', script])` 跑探测脚本，命令输出一切
  正常，但 `DSHA_CHECK_RESULT:<key>:` 的退出码段**恒为空**（收集器兜底 -1）。
- **根因**：`io.Process.start` 走 Windows PATH 解析，`bash` 落到
  `C:\Windows\System32\bash.exe`（WSL 入口）；WSL 的 argv 翻译会吃掉参数里的
  引号——脚本里 `printf '%s' "$code"` 的 `"$code"` 被吞成空参数，printf 以
  空串补 `%s`。脚本本身生成正确（cat -A 验证过），纯传输层损耗。
- **解法**：① shell 显式解析（`DSHA_BASH` → `C:/Program Files/Git/bin/bash.exe`
  → 兜底 `bash`），别让 CreateProcess 掷骰子；② 整段脚本走 **stdin + `bash -s`**
  ，完全绕开 argv 引号翻译（`runtime_bootstrap.dart` 的
  `execRootfsForInstall`）。注意 `bash -s` 的参数表：runner 前缀为空时不能把
  shell 路径再塞进 args（会被当脚本名，退出码 126）。

### 32. shorebird patch 漏 `--dart-define` 会把 DSN 抹空：app 显示「Sentry 未启用」

patch 构建**替换整个 Dart 快照**——发版时 `tool/release.sh` 注入的
`SENTRY_DEFINES`（`--dart-define=SENTRY_DSN=…`）如果 patch 构建没带同款
defines，补丁生效后 `String.fromEnvironment('SENTRY_DSN')` 恒为空，
`SentryBridge.enabled` 为 false（真机「上报诊断」按钮显示「Sentry 未启用，
未上报」实证）。规矩：**热更一律走 `tool/patch.sh <release-version>`**（与
release.sh 同源加载 `tool/sentry.env` 注入 defines；patch 的 defines 必须与
目标 release 一致），不要裸跑 `tool/shorebird.sh patch`。

### 33. 正则迭代器批量 async 化炸文件：多行签名/异形结构必误插

- **现象**：用脚本正则给 `perform` 调用链批量加 `await`/`async`，错误数
  17 → 44 → 70 → 93 不降反升，还产出 `try`/`catch` 语法错（async 被插进
  块中间）。
- **根因**：方法签名跨行、箭头/块混排、修饰词顺序差异——行级正则无法
  识别结构边界，插点全错。
- **解法**：async 传染类改动**手工逐方法**（每改一个跑 analyze）；脚本只
  用于「改前定位清单」（列调用点/方法头），不用于写回。炸了立即
  `git checkout` 止损，不留半损坏文件过夜。

## 六、dsh-go 融合（2026-11 批次 0–4 实证）

### 34. Kotlin FlutterPlugin 不注册进引擎 = MissingPluginException，且兜底文案误导
dsh-go 的 23 个 FlutterPlugin（RuntimePlugin/PhonePlugin/PetOverlayPlugin…）依赖
`engine.plugins.add` 注册（其 MainActivity 真身干这事）。my_app 的 MainActivity 只
手写过自己的 MethodChannel，缺注册时 Dart 侧一切 `dsh/runtime` 调用抛
MissingPluginException，而 onboarding 的 `humanizeRuntimeError(null)` 兜底显示成
「解压时出错」（`shellRuntimeExtractFailed` 是 error 为空的默认文案）——**报错文案
指错方向**，真线索在 Sentry 的 MissingPluginException。融合任何带 FlutterPlugin 的
代码，先数插件注册清单。

### 35. 嵌套 Navigator 下 `Overlay.of(rootOverlay: true)` 的 Consumer 插层会逃出 ProviderScope
dsh-go 的 ChatAlertHost/BackgroundNetHost 把 Consumer 层插到 root overlay——上游
root 即自家 Navigator（ProviderScope 照着）；嵌入 my_app 后 root 是 my_app 的
Navigator，插层落在 ProviderScope **之外** → `No ProviderScope found` → release 白屏
（堆栈在 `ProviderScope.containerOf`）。修法：ProviderScope 提升到 `runApp` 根
（对齐上游 `runApp(ProviderScope(child: DshApp()))` 等价形态），**且不得再有内层
scope**（否则插层与页面用两个 container，状态分裂）。

### 36. 融合代码抬高 Dart 语言特性门槛：SDK 下限与 .fvmrc 解绑
dsh-go 用 null-aware-elements/wildcard `_`（Dart 3.7-3.8+），pubspec `>=3.3` 时 analyze
报 400+ `experiment_not_enabled`/`duplicate_definition`（后者实为 wildcard 未启用）。
对齐其 `^3.13.5`（恰合工具链 D:\flutter 3.13.5）后归零。注意 **.fvmrc 3.41.9（Dart
3.11）不再满足此下限**——AGENTS.md"特性按 pubspec 与 .fvmrc 较低者"的旧规则对融合层失效。

### 37. 图标字体/资产漏搬 = 按钮"显示不出来"
dsh-go 的 `assets/`（3.9MB）含 **DshIcons 图标字体** + JetBrainsMono + 全部 UI 图片，
其图标全靠字体字形。落位时只搬 dart 不搬资产+pubspec fonts/assets 声明 → 所有按钮
图标隐形、UI 图片空白。融合带自定义字体的代码，pubspec 的 fonts 段与 assets 清单
必须同批搬。

### 38. 退役代码的 proot jniLibs 会与新运行时撞包
F1 退役时 `android/app/src/main/jniLibs/` 的 proot 全家桶（libproot.so/libtalloc.so/
libprootloader.so…）漏删，与 dsh-go 的 Termux 版（libproot.so/libtalloc.so **同名**）
共存——Gradle 两来源同名 .so 打包进哪个不确定，错版本 = 运行时安装/启动失败。规则：
换运行时时旧 jniLibs 必须整体清退，打包后 `unzip -l` 验证 `.so` 单一来源。

### 39. MSVC /WX 下第三方包的 UTF-8 源文件炸构建（C4819→C2220）
中文系统代码页 936 下，MSVC 读 UTF-8 源文件报 C4819（字符无法表示），
项目开着 `/W4 /WX`（警告即错误）→ C2220 构建失败。这次是 flutter_webrtc
的 loopback_capturer.h 等文件踩的（第三方包没法改源）。修法（windows/
CMakeLists.txt 的 APPLY_STANDARD_SETTINGS）：加 `/utf-8`（强制 UTF-8 读源）
+ `/wd4819`（双保险）。这是 #2（自家 C++ 禁中文注释）的第三方变体——
**解法升级为全局 /utf-8，而不是禁注释**。

### 40. FFI C ABI 字符串必须 NUL 终止（Rust 侧最容易漏）
Rust 静态 `&str` 直接 `as_ptr()` 给 C ABI 用**没有 \0 尾**——Dart 侧
`toDartString()` 扫到越界字节抛 `FormatException (Missing extension byte)`。
修法：`concat!(..., "\0")` 手动补终止符，或 `CString` 分配。凡是 FFI 返回
字符串，先问"有 NUL 尾吗"。

### 41. 包名 ≠ 入口文件名（import 双查）
`lucide_icons_flutter` 包的入口是 `lucide_icons.dart`（包名和文件名不一致）。
import 写错两轮才定准。**查法**：`ls ~/.pub-cache/hosted/pub.dev/<pkg>-*/lib/`
看实际入口文件，别按包名猜。

### 42. Windows DLL 加载不搜工作目录（flutter test 环境）
`DynamicLibrary.open('core.dll')` 在产品运行时（dll 在 exe 旁）没问题，
但 `flutter test` 的 cwd 是项目根且 Windows DLL 搜索不含 cwd——加载返回 null。
修法：封装层留 `libraryPath` 参数，测试传绝对路径。

### 43. golden 测试的 finder 要锚唯一节点
`find.byType(Row)` 会同时命中测试根 Row 和组件内部 Row（"Found 3 widgets"）。
基准图对 `RepaintBoundary`（`_shot` 唯一包裹层）拍，别对容器类型拍。
另：ShadButton 测试环境必须包 `ShadTheme`（No ShadTheme widget ancestor）。

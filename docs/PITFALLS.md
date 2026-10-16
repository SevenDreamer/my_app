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

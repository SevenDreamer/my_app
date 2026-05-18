# 技术调研笔记

> **注意**：本文档为项目早期（Agent 愿景阶段）的技术调研记录，部分内容已不适用当前项目方向（内置子应用平台）。Flutter 选型、开发环境配置等内容仍有参考价值。

## Flutter 选型依据

### Flutter vs Tauri 对比

| 维度 | Flutter | Tauri |
|------|---------|-------|
| **移动端体验** | 原生级渲染，60FPS，120Hz 动画 | WebView 渲染，复杂列表偶尔掉帧 |
| **插件生态** | 30000+ 插件，硬件全覆盖 | 移动端插件少，大量需自写 |
| **内存占用** | 120MB（空闲） | 45MB（空闲） |
| **包体积** | ~15MB (Android) | ~3-5MB (桌面) |
| **交互体验** | 自绘引擎，手势/动画顶级 | JS→WebView→Rust，多一层延迟 |
| **iOS 后台** | 同样无法保活，只能推送驱动 | 同上 |
| **Rust 集成** | flutter_rust_bridge（桥接） | 原生直接调用 |
| **学习成本** | 需学 Dart | 已熟悉（现有 Tauri 项目） |

**结论**：移动端为主 → Flutter；桌面端为主 → Tauri。本项目以移动端为核心，选 Flutter。

### 性能基准（2026 中端手机测试）

| 指标 | Flutter | Tauri |
|------|---------|-------|
| 冷启动 | 1.2s | 0.8s（桌面） |
| 渲染 FPS（复杂列表） | 60 | 58 |
| 复杂动画 FPS | 60（支持 120Hz） | 58 |
| 10万条 JSON 解析 | 450ms | 280ms（Rust） |
| 电池消耗（30分钟） | 3.2% | — |

数据来源：Oflight Inc. 2026 基准测试

---

## 移动端后台保活

### Android：前台服务

- 插件：flutter_foreground_task / flutter_background_service
- 必须显示通知栏常驻通知
- 需要 WakeLock 保持网络
- 国产 ROM（小米/华为/OPPO/Vivo）有额外杀后台策略，用户需手动关省电

### iOS：推送驱动

- iOS 无长后台服务，App 进入后台后很快被挂起
- 只能通过 APNs 推送唤醒
- Background Fetch：最短 15 分钟一次，不保证准时
- VoIP Push：仅限 VoIP 类应用
- **结论**：iOS 上 Agent 不能持续运行，只能"推送→处理→休眠"

---

## 本地 LLM 推理

### 手机上跑 LLM 的可行性

- 8GB RAM + 骁龙8 Gen2 是实用最低门槛
- 推荐：Qwen3 4B Q4_K_M 量化，~2.5GB
- 推理速度：10-15 tok/s（8GB RAM）
- 关键优化：KV cache 改 q4_0

### 推理引擎选型

| 方案 | 性能 | 集成难度 | Rust 生态 |
|------|------|---------|----------|
| llama.cpp (via llama-cpp-2 crate) | 最好 | 中等 | ✅ 有 Rust 绑定 |
| Candle (HuggingFace 纯 Rust) | 中等 | 简单 | ✅ 原生 Rust |
| MLC-LLM (GPU 加速) | 最好 | 复杂 | ❌ 需 TVM |

**选择**：llama.cpp via Rust，性能最好，生态最成熟

---

## Agent 间通信协议

### A2A Protocol (Agent-to-Agent)

- Google 2025 年开源
- 支持：Agent 发现、能力协商、任务委派、消息传递
- 地址：https://a2a-protocol.org/
- GitHub：https://github.com/a2aproject/A2A

### 消息格式示例

```json
{
  "from": "agent-alpha",
  "to": "agent-beta",
  "type": "task_request",
  "task": {
    "action": "check_storage",
    "params": {}
  }
}
```

---

## Rust Agent 框架

### AutoAgents

- 模块化多 Agent 框架
- 类型安全 + 结构化工具调用
- 可配置记忆 + 多 LLM 后端
- GitHub：https://github.com/liquidos-ai/AutoAgents

### Rig

- 统一 LLM 接口
- 模块化 + 可扩展
- 地址：https://www.rig.rs/

### ADK-Rust

- 生产就绪的 Agent 开发框架
- 模型无关 + 类型安全
- 地址：https://adk-rust.com/

---

## Flutter 开发环境

### 可不装 Android Studio

只需 Android SDK Command-Line Tools：
1. JDK 17（Adoptium）
2. Android SDK cmdline-tools
3. `sdkmanager` 安装 platform/build-tools
4. `flutter config --android-sdk <path>`

### 真机调试优先

- USB 真机调试 > 模拟器体验
- 模拟器必须开 BIOS 虚拟化（VT-x / AMD-V）
- Android 11+ 支持 ADB 无线调试

### Flutter Web 的限制

- dart:io 不可用（Process / File / Directory）
- FFI 不可用
- Rust 只能走 WASM（有硬限制：无文件系统/线程/进程）
- **结论**：Web 端只用于快速验证 UI，真正功能必须在目标平台测试

---

## Flutter 模板项目调研

### 推荐

| 模板 | 特点 | 适用场景 |
|------|------|---------|
| Very Good Core (Mason) | 专业级，严格 lint，完整测试 | 最小化起步 |
| Flutter Boilerplate | 功能全，Firebase/Supabase，Clean Architecture | 功能齐全 |
| MVP Boilerplate | Flutter + Next.js + Supabase 全栈 | 独立开发者 |

### Gradle 坑

无法通过模板完全解决，跟 Flutter SDK 版本绑定：
- Gradle/JDK 版本不兼容
- Android namespace 迁移（AGP 8.0+）
- Kotlin 版本冲突
- minSdkVersion 冲突
- 签名配置

最佳实践：每次 `flutter upgrade` 后，对比 `flutter create` 最新 Android 配置的 diff

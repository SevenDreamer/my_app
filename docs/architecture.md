# 架构设计

## 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                      中继服务器                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  │ 消息路由  │ │ 离线队列  │ │ 状态同步  │ │ 模型训练    │  │
│  │ (A2A协议) │ │          │ │          │ │ /下发服务   │  │
│  └──────────┘ └──────────┘ └──────────┘ └────────────┘  │
└──────────────────────────────────────────────────────────┘
           │                    │                 │
    WebSocket│             WebSocket│         FCM/APNs
           │                    │                 │
┌──────────┼────────────┐  ┌───┼─────────────────┼────────┐
│  主手机 (Agent Alpha)  │  │  副手机 (Agent Beta)          │
│                       │  │                                │
│  ┌─────────────────┐  │  │  ┌─────────────────┐          │
│  │  Flutter UI     │  │  │  │  Flutter UI     │          │
│  │  (完整交互界面)   │  │  │  │  (极简状态面板)   │          │
│  └────────┬────────┘  │  │  └────────┬────────┘          │
│           │           │  │           │                    │
│  ┌────────┴────────┐  │  │  ┌────────┴────────┐          │
│  │  Rust Agent Core│  │  │  │  Rust Agent Core│          │
│  │                 │  │  │  │                 │          │
│  │  ┌───────────┐  │  │  │  │  ┌───────────┐  │          │
│  │  │ 云端LLM   │  │  │  │  │  │ 本地小模型  │  │ ← Qwen3 4B │
│  │  │ (深度推理) │  │  │  │  │  │ (快速响应)  │  │    Q4 量化  │
│  │  └───────────┘  │  │  │  │  └───────────┘  │          │
│  │                 │  │  │  │  ┌───────────┐  │          │
│  │                 │  │  │  │  │ 云端LLM   │  │ ← 复杂问题  │
│  │                 │  │  │  │  │ (按需调用)  │  │    兜底    │
│  │                 │  │  │  │  └───────────┘  │          │
│  │  ┌───────────┐  │  │  │  │                 │          │
│  │  │ RAG 记忆  │  │  │  │  │  ┌───────────┐  │          │
│  │  │ 技能库    │  │  │  │  │  │ RAG 记忆   │  │          │
│  │  └───────────┘  │  │  │  │  │ 技能库     │  │          │
│  │  ┌───────────┐  │  │  │  │  └───────────┘  │          │
│  │  │ 手机操控  │  │  │  │  │  ┌───────────┐  │          │
│  │  │ 系统API   │  │  │  │  │  │ 手机操控   │  │          │
│  │  │ 无障碍服务│  │  │  │  │  │ 无障碍服务 │  │          │
│  │  └───────────┘  │  │  │  │  └───────────┘  │          │
│  └─────────────────┘  │  │  └─────────────────┘          │
│                       │  │                                │
│  前台服务保活 (Android) │  │  前台服务保活 (Android)         │
│  推送驱动 (iOS)        │  │  推送驱动 (iOS)                 │
└───────────────────────┘  └────────────────────────────────┘
```

## 技术选型

### UI 层：Flutter

- 移动端交互体验最好（60FPS / 120Hz 动画）
- 插件生态丰富（30000+，硬件全覆盖）
- 一套代码 Android + iOS + Web + 桌面
- 终端嵌入：xterm.dart + flutter_pty
- 后台保活：flutter_foreground_task

### Agent 核心：Rust

- 编译为原生库（.so / .a），手机直接调用，无需 Python 运行时
- 一套 Rust 代码 → Android / iOS / 桌面 / 服务端 四端复用
- flutter_rust_bridge 桥接 Flutter ↔ Rust

### Agent 间通信：A2A Protocol

- Google 开源的 Agent-to-Agent 通信协议
- 支持 Agent 发现、能力协商、任务委派、消息传递
- 地址：https://a2a-protocol.org/

### 本地模型推理：llama.cpp

- 通过 llama-cpp-2 (Rust crate) 集成到 Rust Agent Core
- 支持 GGUF 格式，Q4_K_M 量化
- 纯 CPU 推理，手机无需 GPU

### LLM API（云端兜底）

- DeepSeek / OpenAI / Claude / Gemini
- Agent Core 统一 LLM 接口，模型可切换

### 中继服务器：Rust

- 消息路由 + 离线队列 + 状态同步 + 推送触发
- 与 Agent Core 共享通信协议代码

## Rust Agent Core 框架备选

| 框架 | 特点 | 地址 |
|------|------|------|
| AutoAgents | 模块化多 Agent，支持多 LLM 后端 | https://github.com/liquidos-ai/AutoAgents |
| Rig | 统一 LLM 接口，模块化 | https://www.rig.rs/ |
| ADK-Rust | 生产就绪，类型安全 | https://adk-rust.com/ |

## Flutter 端依赖规划

```yaml
dependencies:
  # 状态管理
  flutter_riverpod: ^2.x
  
  # 路由
  go_router: ^14.x
  
  # 网络
  dio: ^5.x
  
  # Rust 桥接
  flutter_rust_bridge: ^2.x
  
  # 后台保活 (Android)
  flutter_foreground_task: ^8.x
  
  # 本地通知
  flutter_local_notifications: ^18.x
  
  # 终端 (可选)
  xterm: ^4.x
  flutter_pty: ^0.x
  
  # 本地存储
  hive: ^4.x
  
  # 推送
  firebase_messaging: ^15.x
```

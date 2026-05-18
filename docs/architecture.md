# 架构设计

## 整体架构

```
┌─────────────────────────────────────────────────┐
│              Flutter (UI Layer)                 │
│                                                 │
│  ┌──────────────┐  ┌──────────────────────┐   │
│  │  core/       │  │  features/           │   │
│  │  (启动器页面) │  │  (各子应用模块)        │   │
│  │              │  │  ├─ chat/             │   │
│  │  theme/      │  │  ├─ image/            │   │
│  │  models/     │  │  ├─ code/             │   │
│  │  services/   │  │  ├─ database/         │   │
│  │              │  │  └─ bar/              │   │
│  └──────┬───────┘  └──────────┬───────────┘   │
│         │                      │                  │
│         └──────────┬───────────┘                  │
│                    │                              │
│         ┌──────────▼───────────┐                  │
│         │   rust/ (FFI Layer)  │                  │
│         │  ffi_manual.dart      │                  │
│         │  api/simple.dart      │                  │
│         └──────────┬───────────┘                  │
└────────────────────┼──────────────────────────────┘
                     │ dart:ffi
┌────────────────────▼──────────────────────────────┐
│              Rust (Native Library)                 │
│                                                   │
│  rust/                                             │
│  ├── src/                                          │
│  │   ├── api/  (对外接口)                          │
│  │   └── ...                                       │
│  └── Cargo.toml                                    │
└───────────────────────────────────────────────────┘
```

## 核心设计

### 子应用注册机制

所有子应用通过 `SubApp` 模型在 `app_launcher_screen.dart` 中集中注册：

```dart
final List<SubApp> _apps = [
  SubApp(id: 'chat', name: '聊天助手', builder: ChatApp.new, ...),
  // ...
];
```

`SubApp` 模型包含：`id`、`name`、`description`、`icon`、`color`、`builder`（Widget 构建函数）。

### 目录职责

| 目录 | 职责 |
|------|------|
| `core/models/` | 公共模型（`SubApp` 等） |
| `core/screens/` | 核心页面（启动器、设置等） |
| `core/services/` | 全局服务（更新、配置等） |
| `core/theme/` | 主题定义 |
| `features/<name>/` | 各子应用的完整代码 |
| `rust/` | Rust FFI 绑定层 |

### 子应用模块结构

每个 `features/<name>/` 内部可按需细分：

```
features/bar/
├── bar_app.dart        # 子应用入口
├── screens/            # 页面
├── services/           # 业务逻辑
└── widgets/            # 局部组件
```

不是所有子应用都需要 `screens/services/widgets`——简单子应用可以只有一个 `<name>_app.dart`。

## 技术选型

### Flutter 端

| 依赖 | 用途 |
|------|------|
| `flutter_rust_bridge` | Dart ↔ Rust FFI 桥接 |
| `heroui_design_system` | 统一设计系统 |
| `lucide_flutter` | 图标库 |
| `sqflite_common_ffi` | SQLite（桌面端） |
| `postgres` | PostgreSQL 驱动 |
| `mysql1` | MySQL 驱动 |
| `mongo_dart` | MongoDB 驱动 |
| `shared_preferences` | 本地配置存储 |

### Rust 端

- 编译为各平台原生库（Windows `.dll`、macOS `.dylib`、Linux `.so`）
- 通过 `flutter_rust_bridge` 自动生成 Dart 绑定
- 适合：文件操作、系统调用、计算密集型任务

## 数据流

```
用户操作
  │
  ▼
Flutter UI (features/<name>/)
  │
  ├── 纯 Dart 逻辑（直接处理）
  │
  └── 需要原生能力
        │
        ▼
  rust/ffi_manual.dart 或 rust/api/simple.dart
        │
        ▼
  Rust Native Library (rust/src/)
        │
        ▼
  系统 API / 文件 / 计算...
```

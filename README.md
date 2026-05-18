# My App

内置多子应用的 Flutter + Rust 桌面应用平台。所有子应用内置在主应用中，通过启动器页面选择切换。

## 子应用列表

| 子应用 | 说明 |
|--------|------|
| 聊天助手 | AI 智能对话 |
| 图片处理 | AI 图片编辑工具 |
| 代码助手 | AI 代码生成与优化 |
| 数据库管理 | 多类型数据库浏览与管理（SQLite / PostgreSQL / MySQL / MongoDB） |
| 酒吧系统 | 酒吧点单与管理 |

## 技术栈

- **UI**: Flutter 3 + Material 3
- **核心逻辑**: Rust（通过 FFI 调用）
- **桥接**: `flutter_rust_bridge`
- **设计系统**: HeroUI Design System
- **图标**: Lucide Flutter

## 目录结构

```
lib/
├── main.dart                 # 入口
├── core/                    # 主应用核心
│   ├── models/              # 公共模型（SubApp 等）
│   ├── screens/             # 核心页面（启动器）
│   ├── services/            # 核心服务（更新服务等）
│   └── theme/              # 主题配置
├── features/                # 各子应用模块
│   ├── bar/                 # 酒吧系统
│   ├── chat/                # 聊天助手
│   ├── code/                # 代码助手
│   ├── database/            # 数据库管理
│   └── image/               # 图片处理
└── rust/                   # Rust FFI 绑定
    ├── api/                 # 自动生成的 Rust 接口
    └── ffi_manual.dart      # 手动 FFI 绑定
```

## 开发

```bash
# 安装依赖
flutter pub get

# 运行（Windows）
flutter run -d windows

# 构建
flutter build windows
```

## Rust 集成

Rust 核心代码位于 `rust/` 目录，通过 `flutter_rust_bridge` 生成 Dart 绑定：

```bash
# 生成 FFI 绑定（需要先安装 flutter_rust_bridge_codegen）
dart run flutter_rust_bridge_codegen
```

## 添加新子应用

1. 在 `lib/features/` 下创建子目录（如 `my_app/`）
2. 创建 `<my_app>_app.dart` 作为入口组件
3. 在 `lib/core/screens/app_launcher_screen.dart` 的 `_apps` 列表中注册

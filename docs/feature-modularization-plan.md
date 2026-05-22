# 功能模块化改造方案

> 目标：将各功能模块改为可选加载，禁用时无需修改业务代码，Rust 动态库不存在时自动静默禁用。

---

## 一、改造目标

### 当前问题
- Hermes 等功能依赖 Rust 动态库（`hermes_api.dll`），库不存在时启动崩溃
- 禁用功能需要注释多处代码（路由、应用列表、初始化等），容易遗漏

### 改造后效果
- ✅ 功能入口自动根据 Rust 库是否可用显示/隐藏
- ✅ 初始化失败不崩溃，静默禁用
- ✅ 新增功能只需在 `FeatureRegistry` 注册，无需修改多处代码

---

## 二、架构设计

```
┌─────────────────────────────────────────────┐
│              Flutter App                   │
│                                           │
│  main.dart                                │
│    ├─ RustLib.init()          (主库)     │
│    └─ tryInitHermes()        (可选)     │
│         └─ 捕获异常 → 静默禁用            │
│                                           │
│  FeatureRegistry                          │
│    ├─ registerApp('hermes', ...)          │
│    └─ visibleApps   (过滤不可用功能)     │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│              Rust Workspace                │
│                                           │
│  my_app (cdylib)        ← 始终编译       │
│  hermes_api (cdylib)    ← 可选编译       │
│    └─ hermes_api.dll     ← 不存在时禁用   │
└─────────────────────────────────────────────┘
```

---

## 三、实施步骤

### ✅ Step 1：创建 `FeatureRegistry`（已完成）
- [x] 创建 `lib/core/config/feature_registry.dart`
- [x] 提供 `registerApp` / `visibleApps` / `isAppAvailable`

### Step 2：改造 `main.dart` 初始化逻辑
**文件**：`lib/main.dart`

**改造内容**：
```dart
// 改造前
await RustLib.init();
await hermes_rust.RustLib.init(); // ❌ 崩溃

// 改造后
await RustLib.init(); // ✅ 主库
await FeatureRegistry.tryInitFeature('hermes'); // ✅ 失败不崩溃
```

- [ ] 移除 `hermes_rust` 导入
- [ ] 添加 `FeatureRegistry.tryInitFeature()` 调用
- [ ] 将 `hermesAvailable` 状态传递给 `MyApp`

### Step 3：改造 `app_data.dart` 应用列表
**文件**：`lib/core/models/app_data.dart`

**改造内容**：
```dart
// 改造后
List<SubApp> get visibleApps => builtInApps
    .where((app) => FeatureRegistry.isAppAvailable(app.id))
    .toList();
```

- [ ] 添加 `visibleApps` getter
- [ ] 保留 `builtInApps` 常量（完整列表）

### Step 4：改造 `app_launcher_screen.dart`
**文件**：`lib/core/screens/app_launcher_screen.dart`

**改造内容**：
- [ ] 使用 `FeatureRegistry.visibleApps` 替代直接引用 `builtInApps`
- [ ] 移除 `_onAppTap` 中的硬编码 switch

### Step 5：改造 `app_router.dart`
**文件**：`lib/core/router/app_router.dart`

**改造内容**：
- [ ] 路由守卫中检查功能是否可用
- [ ] 不可用的路由重定向到 launcher

### Step 6：Rust 侧 `hermes_api` 可选编译
**文件**：`rust/Cargo.toml`、`rust/hermes_api/`

**改造内容**：
- [ ] 确保 `hermes_api` 是独立 crate，不影响主库编译
- [ ] 文档说明如何单独编译 `hermes_api`

### Step 7：添加功能开关配置（可选）
**文件**：`lib/core/config/feature_flags.dart`

**改造内容**：
- [ ] 支持 `--dart-define=ENABLE_HERMES=true` 强制启用
- [ ] 支持配置文件控制功能开关

---

## 四、文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/main.dart` | 修改 | 分离主库和可选库初始化 |
| `lib/core/config/feature_registry.dart` | 新建 | 功能注册与可用状态管理 |
| `lib/core/models/app_data.dart` | 修改 | 添加 `visibleApps` getter |
| `lib/core/screens/app_launcher_screen.dart` | 修改 | 使用 `visibleApps` |
| `lib/core/router/app_router.dart` | 修改 | 路由守卫检查功能可用性 |
| `lib/rust/hermes/api.dart` | 修改 | 添加 `tryInitHermes()` |
| `rust/Cargo.toml` | 修改 | 确认 workspace 配置 |
| `docs/feature-modularization-plan.md` | 新建 | 本文件 |

---

## 五、测试计划

- [ ] Hermes Rust 库存在时，功能正常可用
- [ ] Hermes Rust 库不存在时，入口自动隐藏，无崩溃
- [ ] 其他功能（image、bar、database）不受影响
- [ ] Hot Reload 后状态正确

---

## 六、使用说明

### 启用 Hermes 功能

1. **编译 Rust 动态库**：
   ```bash
   cd d:/Projects/my_app/rust
   cargo build -p hermes_api
   ```
   编译成功后，`hermes_api.dll` 会生成在 `rust/target/debug/` 或 `rust/target/release/`。

2. **Flutter 启动时自动检测**：
   - 如果 `hermes_api.dll` 存在且加载成功 → Hermes 入口自动显示
   - 如果不存在 → 自动隐藏，无崩溃

### 禁用 Hermes 功能

- 不编译 `hermes_api` crate 即可
- 或者删除 `rust/target/**/hermes_api.dll`

### 添加新功能模块

1. 在 `app_data.dart` 的 `builtInApps` 中添加 `SubApp`
2. 在 `FeatureRegistry` 中注册功能
3. 在 `app_router.dart` 中添加路由
4. 功能包初始化时调用 `FeatureRegistry.setAvailable('xxx', true)`

---

## 七、进度记录

- **2026-05-22 10:37** 创建文档，开始实施
- **Step 1** ✅ 已完成（FeatureRegistry 已创建）
- **Step 2** ✅ 已完成（main.dart 改造完毕）
- **Step 3** ✅ 已完成（app_data.dart 添加 visibleApps getter）
- **Step 4** ✅ 已完成（app_launcher_screen.dart 使用 visibleApps）
- **Step 5** ✅ 已完成（app_router.dart 恢复 hermes 路由，添加功能检查）
- **Step 6** ✅ 已完成（Rust 侧 hermes_api 已是可选编译）

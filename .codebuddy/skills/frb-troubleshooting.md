# Flutter Rust Bridge 问题排查与修复 Skill

## 概述

本 Skill 记录了 Flutter Rust Bridge (FRB) 2.x 在 Windows 平台上常见的编译问题及其解决方案。当你遇到 FRB 相关的编译错误时，可以参考本文档进行排查和修复。

---

## 问题 1：符号重复定义 (Symbol Already Defined)

### 症状

运行 `cargo build` 时出现以下错误：

```
error: symbol `frb_get_rust_content_hash` is already defined
  --> rust\src\frb_generated.rs:XX:XX
```

或类似的：
```
error: symbol `frb_pde_ffi_dispatcher_primary` is already defined
error: symbol `frb_pde_ffi_dispatcher_sync` is already defined
```

### 原因分析

`frb_generated.rs` 文件中存在**重复的符号定义**：

1. **文件头部**：`frb_generated_boilerplate!()` 宏 + 手动定义的 FFI 导出函数
2. **io 模块内部**：`frb_generated_boilerplate_io!()` 宏也定义了相同的符号

这两处定义产生冲突，导致链接器报错。

### 具体表现

查看 `rust/src/frb_generated.rs` 文件，你会看到类似这样的结构：

```rust
// 文件头部 (~第 36-70 行)
flutter_rust_bridge::frb_generated_boilerplate!(
    default_stream_sink_codec = SseCodec,
    default_rust_opaque = RustOpaqueMoi,
    default_rust_auto_opaque = RustAutoOpaqueMoi,
);
pub const FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "2.12.0";
pub const FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = -390374125;

// ❌ 这些手动定义的函数会与 io 模块中的宏产生冲突
#[no_mangle]
pub extern "C" fn frb_get_rust_content_hash() -> i32 {
    FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH
}

#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_primary(...) { ... }

#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_sync(...) { ... }

// ... 中间代码 ...

// 文件末尾 (~第 1200+ 行)
mod io {
    // ...
    flutter_rust_bridge::frb_generated_boilerplate_io!();  // ❌ 这里也定义了相同的符号
}
```

### 解决方案

**删除文件头部手动定义的 FFI 导出函数**，只保留 `io` 模块内的宏定义。

#### 步骤 1：定位问题代码

打开 `rust/src/frb_generated.rs`，找到文件头部（大约第 36-70 行）的以下代码：

```rust
flutter_rust_bridge::frb_generated_boilerplate!(
    default_stream_sink_codec = SseCodec,
    default_rust_opaque = RustOpaqueMoi,
    default_rust_auto_opaque = RustAutoOpaqueMoi,
);
pub const FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "2.12.0";
pub const FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = -390374125;

// FFI exports for Flutter FFI  <-- 这部分需要删除
#[no_mangle]
pub extern "C" fn frb_get_rust_content_hash() -> i32 {
    FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH
}

#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_primary(
    func_id: i32,
    port: flutter_rust_bridge::for_generated::MessagePort,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) {
    frb_pde_ffi_dispatcher_primary_impl(func_id, port, ptr, rust_vec_len, data_len)
}

#[no_mangle]
pub extern "C" fn frb_pde_ffi_dispatcher_sync(
    func_id: i32,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    frb_pde_ffi_dispatcher_sync_impl(func_id, ptr, rust_vec_len, data_len)
}
```

#### 步骤 2：删除重复的函数定义

将上面的代码修改为只保留常量定义：

```rust
flutter_rust_bridge::frb_generated_boilerplate!(
    default_stream_sink_codec = SseCodec,
    default_rust_opaque = RustOpaqueMoi,
    default_rust_auto_opaque = RustAutoOpaqueMoi,
);
pub const FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "2.12.0";
pub const FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = -390374125;
```

#### 步骤 3：重新编译

```bash
cd d:\Projects\my_app\rust
cargo build --release
```

---

## 问题 2：函数名称不匹配

### 症状

```
error[E0425]: cannot find function `frb_pde_ffi_dispatcher_primary_impl` in this scope
error[E0425]: cannot find function `frb_pde_ffi_dispatcher_sync_impl` in this scope
```

### 原因分析

FRB codegen 生成的代码中，外部调用函数名带有 `frb_` 前缀（如 `frb_pde_ffi_dispatcher_primary_impl`），但实际定义的函数名没有这个前缀（`pde_ffi_dispatcher_primary_impl`）。

### 解决方案

如果你需要保留手动定义的 FFI 导出函数，需要将调用名称从 `frb_pde_ffi_dispatcher_*_impl` 改为 `pde_ffi_dispatcher_*_impl`：

```rust
// ❌ 错误的调用
frb_pde_ffi_dispatcher_primary_impl(func_id, port, ptr, rust_vec_len, data_len)

// ✅ 正确的调用
pde_ffi_dispatcher_primary_impl(func_id, port, ptr, rust_vec_len, data_len)
```

**但更推荐的做法是直接删除这些手动定义的函数**（见问题 1 的解决方案），让 `io` 模块内的 `frb_generated_boilerplate_io!()` 宏自动处理。

---

## 问题 3：DLL 文件被占用无法覆盖

### 症状

```
error: could not copy "...\my_app.dll" to "...\my_app.dll": Access is denied. (os error 5)
```

### 原因分析

之前运行的 Flutter 应用程序或调试进程仍在运行，占用了 DLL 文件。

### 解决方案

#### 方法 1：杀死占用进程

```powershell
taskkill /f /im my_app.exe
```

#### 方法 2：关闭所有 Flutter 相关进程

```powershell
# 查找并关闭 Flutter 相关进程
taskkill /f /im flutter.exe 2>$null
taskkill /f /im dart.exe 2>$null
taskkill /f /im my_app.exe 2>$null
```

#### 方法 3：重启 IDE

关闭并重新打开 VS Code 或其他 IDE。

---

## 完整修复流程

当你遇到 FRB 编译问题时，按以下流程操作：

### 第一步：重新生成 FRB 绑定代码

```bash
cd d:\Projects\my_app
flutter_rust_bridge_codegen generate
```

### 第二步：检查并修复 frb_generated.rs

1. 打开 `rust/src/frb_generated.rs`
2. 查找文件头部是否有手动定义的 FFI 函数（`frb_get_rust_content_hash`、`frb_pde_ffi_dispatcher_*`）
3. 如果有，删除这些函数，只保留常量定义和 boilerplate 宏

### 第三步：杀死占用 DLL 的进程

```powershell
taskkill /f /im my_app.exe 2>$null
```

### 第四步：编译 Rust 库

```bash
cd d:\Projects\my_app\rust
cargo build --release
```

### 第五步：构建 Flutter 应用

```bash
cd d:\Projects\my_app
flutter build windows --release
```

### 第六步：运行测试

```bash
flutter run -d windows
```

---

## 预防措施

### 1. 不要手动修改生成的文件

`rust/src/frb_generated.rs` 和 `lib/rust/frb_generated.dart` 是自动生成的文件。任何手动修改都会在下次运行 `flutter_rust_bridge_codegen generate` 时被覆盖。

如果你发现生成的代码有问题，应该：
1. 检查 `flutter_rust_bridge.yaml` 配置
2. 更新 `flutter_rust_bridge_codegen` 工具
3. 如果是工具本身的 bug，向官方或我们的 Fork 提交 issue

### 2. 使用我们的 Fork 版本

我们维护的 Fork 已经修复了 Windows 上的多个已知问题：

```bash
# 安装自定义版本
git clone git@github.com:SevenDreamer/flutter_rust_bridge.git
cd flutter_rust_bridge/frb_codegen
cargo install --path .
```

### 3. 开发前清理旧进程

在开始开发前，确保没有旧的应用进程在运行：

```powershell
taskkill /f /im my_app.exe 2>$null
```

---

## 常用命令速查

| 操作 | 命令 |
|------|------|
| 生成 FRB 绑定 | `flutter_rust_bridge_codegen generate` |
| 监听文件变化自动生成 | `flutter_rust_bridge_codegen generate --watch` |
| 编译 Rust (Debug) | `cd rust && cargo build` |
| 编译 Rust (Release) | `cd rust && cargo build --release` |
| 清理 Rust 构建 | `cd rust && cargo clean` |
| 构建 Flutter Windows | `flutter build windows --release` |
| 运行 Flutter Windows | `flutter run -d windows` |
| 杀死应用进程 | `taskkill /f /im my_app.exe` |

---

## 相关文件

- `flutter_rust_bridge.yaml` - FRB 配置文件
- `rust/src/frb_generated.rs` - Rust 端生成的绑定代码
- `lib/rust/frb_generated.dart` - Dart 端生成的绑定代码
- `lib/rust/frb_generated.io.dart` - Dart IO 平台绑定
- `rust/Cargo.toml` - Rust 依赖配置

---

## 更新日志

### 2026-05-21
- ✅ 记录符号重复定义问题及解决方案
- ✅ 记录函数名称不匹配问题及解决方案
- ✅ 记录 DLL 文件占用问题及解决方案
- ✅ 创建完整修复流程

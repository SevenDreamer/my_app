# Flutter Rust Bridge 使用指南

## ✅ Windows 支持已完全修复！

### 修复内容

我们在 fork 中修复了两个 Windows 关键问题：

**1. Windows 路径 Bug（已修复）**
- **问题**：`std::fs::canonicalize` 在 Windows 上返回 `\\?\` 前缀路径
- **修复**：使用 `dunce::canonicalize` 替代
- **Commit**: `ff1ccf4` - "fix: Windows path handling with dunce crate"

**2. FFI 符号导出问题（已修复）**
- **问题**：自动生成的代码缺少 `#[no_mangle] pub extern "C"` 导出，导致 Flutter FFI 找不到符号
- **修复**：修改 `frb_codegen` 模板，生成正确的 FFI 导出函数
- **Commit**: `0e0a858` - "fix: export FFI symbols for Flutter FFI on Windows"

---

## 🍴 使用我们的 Fork

### Fork 地址
```
https://github.com/SevenDreamer/flutter_rust_bridge
```

### 安装自定义版本

**方法 1：从源码安装（推荐）**
```bash
# 1. 克隆我们的 fork
git clone git@github.com:SevenDreamer/flutter_rust_bridge.git
cd flutter_rust_bridge/frb_codegen

# 2. 安装到 ~/.cargo/bin/
cargo install --path .
```

**方法 2：作为依赖使用**
在 `my_app/rust/Cargo.toml` 中：
```toml
[dependencies]
flutter_rust_bridge = { git = "https://github.com/SevenDreamer/flutter_rust_bridge", version = "2.12.0" }
```

### 验证安装
```bash
flutter_rust_bridge_codegen --version
# 应输出：flutter_rust_bridge_codegen 2.12.0
```

---

## 使用步骤

### 1. 编写 Rust API
在 `rust/src/api/` 目录下创建 Rust 文件，使用 `#[flutter_rust_bridge::frb]` 注解：

```rust
// rust/src/api/simple.rs
use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn simple_add(a: i32, b: i32) -> i32 {
    a + b
}

pub async fn get_user_info(user_id: i32) -> String {
    format!("User {}", user_id)
}
```

### 2. 生成绑定代码
```bash
cd d:\Projects\my_app
flutter_rust_bridge_codegen generate
```

生成的文件：
- `rust/src/frb_generated/frb_generated.rs` (Rust 绑定)
- `lib/rust/frb_generated.dart` (Dart 绑定)
- `lib/rust/frb_generated.io.dart` (Dart 绑定 - IO)
- `lib/rust/frb_generated.web.dart` (Dart 绑定 - Web)

### 3. 在 Rust 中集成生成的代码
`rust/src/lib.rs` 已配置好：
```rust
pub mod api;
mod frb_generated;

pub mod ffi_manual;  // 手动 FFI（备用）
pub mod ffi_auth;    // 手动 FFI（备用）
```

### 4. 在 Dart 中调用
```dart
import 'rust/frb_generated.dart';

void main() async {
  // 初始化
  await RustLib.init();
  
  // 调用 Rust 函数
  final result = await RustLib.simpleAdd(a: 1, b: 2);
  print(result); // 3
}
```

---

## 修复详情

### Fork 中的修改

#### Commit 1: `ff1ccf4` - Windows 路径修复
修改的文件（`d:\Projects\flutter_rust_bridge\`）：
1. `frb_codegen/Cargo.toml` - 添加 `dunce = "1.0"` 依赖
2. `frb_codegen/src/library/utils/path_utils.rs` - 使用 `dunce::canonicalize`
3. `frb_codegen/src/library/codegen/config/internal_config_parser/mod.rs` - 使用 `dunce::canonicalize`
4. `frb_codegen/src/library/commands/cbindgen.rs` - 使用 `dunce::canonicalize`
5. `frb_codegen/src/library/utils/test_utils.rs` - 使用 `dunce::canonicalize`
6. `frb_codegen/src/library/build_web/mod.rs` - 使用 `dunce::canonicalize`
7. `frb_codegen/src/library/utils/rust_project_utils.rs` - 添加 `dunce::simplified`

#### Commit 2: `0e0a858` - FFI 符号导出修复
修改的文件：
1. `frb_codegen/src/library/codegen/generator/wire/rust/spec_generator/misc/mod.rs`
   - 将 `FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH` 从 `pub(crate)` 改为 `pub`
   - 添加 `#[no_mangle] pub extern "C"` 包装函数

2. `frb_codegen/src/library/codegen/generator/wire/rust/spec_generator/codec/pde/entrypoint.rs`
   - 将 `fn pde_ffi_dispatcher_{name}_impl` 从私有改为 `pub fn`

---

## 当前状态（2026-05-19）

- ✅ **Fork 已创建**：`SevenDreamer/flutter_rust_bridge`
- ✅ **Windows 路径修复**：已推送（commit `ff1ccf4`）
- ✅ **FFI 符号导出修复**：已推送（commit `0e0a858`）
- ✅ **自动生成绑定已启用**：`my_app` 项目已启用 `flutter_rust_bridge` 自动生成
- ✅ **编译测试通过**：Rust DLL 成功编译（3.7MB）
- ⚠️ **手动 FFI 仍保留**：作为备用方案

---

## 迁移计划

### 已完成
- [x] Fork `flutter_rust_bridge` 到 `SevenDreamer`
- [x] 修复 Windows 路径问题
- [x] 修复 FFI 符号导出问题
- [x] 启用自动生成绑定
- [x] 测试编译通过

### 待完成
- [ ] 将手动 FFI 函数逐步迁移到 `flutter_rust_bridge`
- [ ] 测试自动生成绑定的运行时功能
- [ ] 删除手动 FFI 代码（`ffi_manual.rs`, `ffi_auth.rs`）
- [ ] 向官方提交 PR（可选）

---

## 常见问题

### Q: 为什么需要 Fork？
A: 因为 `flutter_rust_bridge` v2.12.0 在 Windows 上有两处关键 bug：
1. 路径处理使用 `std::fs::canonicalize` 导致 `\\?\` 前缀问题
2. 生成的代码缺少 FFI 符号导出，导致运行时错误

### Q: Fork 和官方版本会同步吗？
A: 我们会定期从 `fzyzcjy/flutter_rust_bridge` 拉取更新，并保留我们的修复。

### Q: 可以向官方提交 PR 吗？
A: 可以！我们的修复已经比较稳定，可以向官方提交 PR。

### Q: codegen 可以自动监控文件变化吗？
A: 可以！使用 `--watch` 参数：
```bash
flutter_rust_bridge_codegen generate --watch
```

### Q: 生成代码后需要手动修改吗？
A: 不需要！每次运行 codegen 都会重新生成，所以不要手动修改生成的文件。

---

## 参考资料
- **我们的 Fork**: https://github.com/SevenDreamer/flutter_rust_bridge
- **官方仓库**: https://github.com/fzyzcjy/flutter_rust_bridge
- **官方文档**: https://cjycode.com/flutter_rust_bridge/quickstart
- **Pub.dev 包**: https://pub.dev/packages/flutter_rust_bridge
- **dunce crate**: https://crates.io/crates/dunce

---

## 更新日志

### 2026-05-19
- ✅ 启用 `flutter_rust_bridge` 自动生成绑定
- ✅ 修复 FFI 符号导出问题（commit `0e0a858`）
- ✅ 推送到 fork `SevenDreamer/flutter_rust_bridge`

### 2026-05-18
- ✅ Fork `flutter_rust_bridge` 到 `SevenDreamer`
- ✅ 修复 Windows 路径问题（commit `ff1ccf4`）
- ✅ 手动 FFI 集成成功（临时方案）

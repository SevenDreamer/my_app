# Flutter Rust Bridge 使用指南

## Windows 路径 Bug 已修复！✅

### 问题回顾
`flutter_rust_bridge_codegen v2.12.0` 在 Windows 上运行时会报错：
```
Error: When compute_mod_from_rust_path(code_path=..., base_dir="\\\\?\\D:\\Projects\\my_app\\rust\\src")
    prefix not found
```

**问题原因**：Rust 的 `std::fs::canonicalize` 在 Windows 上返回 `\\?\` 前缀的路径（extended-length path prefix），但 `flutter_rust_bridge_codegen` 无法正确处理这个前缀。

### 已修复！
我们修改了 `flutter_rust_bridge_codegen` 源码，使用 `dunce::canonicalize` 代替 `std::fs::canonicalize`，彻底解决了 Windows 路径前缀问题。

**修复后的版本已安装到 `~/.cargo/bin/`，可以直接使用。**

---

## 使用步骤

### 1. 确认安装
```bash
flutter_rust_bridge_codegen --version
# 应输出：flutter_rust_bridge_codegen 2.12.0（修复版）
```

### 2. 配置 `flutter_rust_bridge.yaml`
项目根目录下的配置：
```yaml
base_dir: "."
rust_input: "crate::api"
rust_root: "rust/"
rust_output: "rust/src/frb_generated/frb_generated.rs"
dart_output: "lib/rust/"
```

### 3. 编写 Rust API
在 `rust/src/api/` 目录下创建 Rust 文件，使用 `#[flutter_rust_bridge::frb]` 注解：

```rust
// rust/src/api/simple.rs
use flutter_rust_bridge::frb;

#[frb]
pub fn simple_add(a: i32, b: i32) -> i32 {
    a + b
}

#[frb]
pub async fn get_user_info(user_id: i32) -> String {
    format!("User {}", user_id)
}
```

### 4. 生成绑定代码
```bash
cd d:\Projects\my_app
flutter_rust_bridge_codegen generate
```

生成的文件：
- `rust/src/frb_generated/frb_generated.rs` (Rust 绑定)
- `lib/rust/rust_generated.dart` (Dart 绑定)
- `lib/rust/rust_generated.io.dart` (Dart 绑定 - IO)
- `lib/rust/rust_generated.web.dart` (Dart 绑定 - Web)

### 5. 在 Rust 中集成生成的代码
修改 `rust/src/lib.rs`：
```rust
// 引入生成的代码
mod frb_generated;

// 引入 API 模块
pub mod api;

// 初始化函数（供 Dart 调用）
pub fn init_app() {
    flutter_rust_bridge::setup();
}
```

### 6. 在 Dart 中调用
```dart
import 'rust/rust_generated.dart';

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

### 修改的文件（`d:\Projects\flutter_rust_bridge\`）
1. **`frb_codegen/Cargo.toml`** - 添加 `dunce = "1.0"` 依赖
2. **`frb_codegen/src/library/utils/path_utils.rs`** - 修改 `canonicalize_with_error_message` 使用 `dunce::canonicalize`
3. **`frb_codegen/src/library/codegen/config/internal_config_parser/mod.rs`** - 修改第 30 行使用 `dunce::canonicalize`
4. **`frb_codegen/src/library/commands/cbindgen.rs`** - 修改第 95 行使用 `dunce::canonicalize`
5. **`frb_codegen/src/library/utils/test_utils.rs`** - 修改第 12 行使用 `dunce::canonicalize`
6. **`frb_codegen/src/library/build_web/mod.rs`** - 修改第 30 行使用 `dunce::canonicalize`
7. **`frb_codegen/src/library/utils/rust_project_utils.rs`** - 添加 `dunce::simplified` 作为双重保险

### 编译并安装修复版
```bash
# 1. 编译
cd d:\Projects\flutter_rust_bridge\frb_codegen
cargo build --release

# 2. 复制到 ~/.cargo/bin/
Copy-Item -Path "target\release\flutter_rust_bridge_codegen.exe" `
         -Destination "$env:USERPROFILE\.cargo\bin\" -Force
```

---

## 项目迁移计划

### 当前状态
- ✅ `flutter_rust_bridge` Dart 包已安装 (v2.12.0)
- ✅ `flutter_rust_bridge_codegen` 工具已修复并安装 (v2.12.0 修复版)
- ✅ 测试运行 `flutter_rust_bridge_codegen generate` 成功（输出 `Done!`）
- ⚠️ 手动 FFI 绑定仍在使用（`ffi_auth.rs`, `ffi_auth.dart`）
- ⚠️ `frb_generated.rs` 已被生成，但尚未被引用

### 迁移步骤
1. **测试 codegen 输出**
   - 检查生成的 `rust/src/frb_generated/frb_generated.rs`
   - 检查生成的 `lib/rust/rust_generated.dart`

2. **迁移认证模块**
   - 将 `rust/src/auth.rs` 中的函数迁移到 `rust/src/api/auth.rs`
   - 添加 `#[frb]` 注解
   - 运行 codegen 生成绑定

3. **更新 Dart 代码**
   - 删除 `lib/rust/ffi_auth.dart`（手动绑定）
   - 使用生成的 `RustLib` 类

4. **清理**
   - 删除 `rust/src/ffi_auth.rs`（手动 FFI）
   - 删除 `rust/src/ffi_manual.rs`（手动 FFI）
   - 删除 `rust/src/macros.rs`（不再需要）

---

## 常见问题

### Q: 修复会合并到官方版本吗？
A: 我们建议向 `flutter_rust_bridge` 提交 PR，将 `dunce` 集成到官方版本中。

### Q: codegen 可以自动监控文件变化吗？
A: 可以！使用 `--watch` 参数：
```bash
flutter_rust_bridge_codegen generate --watch
```

### Q: 生成代码后需要手动修改吗？
A: 不需要！每次运行 codegen 都会重新生成，所以不要手动修改生成的文件。

---

## 参考资料
- 官方文档：https://cjycode.com/flutter_rust_bridge/quickstart
- Pub.dev 包：https://pub.dev/packages/flutter_rust_bridge
- GitHub：https://github.com/fzyzcjy/flutter_rust_bridge
- `dunce` crate：https://crates.io/crates/dunce

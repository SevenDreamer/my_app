# 功能想法记录

记录 my_app 项目待实现的功能想法和计划。

**项目说明**：my_app 是一个个人多功能应用平台，会集成多个个人角色需要的功能模块（如 Hermes Agent 等）。

## 状态说明

- 📝 **待评估** - 想法阶段，需要详细设计
- 🔄 **待实现** - 已确认，等待开发
- 🚧 **进行中** - 正在开发
- ✅ **已完成** - 已实现并上线

---

## 功能列表

### 🔄 生物识别认证（指纹/人脸识别）

**提出日期**: 2026-05-19  
**优先级**: 中  
**状态**: 待实现

#### 功能描述

在 my_app 平台中集成生物识别认证功能，支持：
- 指纹识别（Touch ID / 指纹传感器）
- 面部识别（Face ID / Windows Hello）
- 设备密码/PIN 码作为备选方案

此功能可作为多个功能模块（包括 Hermes Agent）的统一认证方式。

#### 技术实现

**Flutter 端**:
- 使用 `local_auth` 插件实现生物识别
- 支持平台：iOS、Android、Windows、macOS
- 需要配置平台权限和 Info.plist/AndroidManifest.xml

**Rust 端**:
- 生物识别成功后，生成/验证认证令牌
- 与现有认证系统（如 JWT）集成
- 安全存储认证状态

#### 使用场景

1. 应用启动时的身份验证
2. 敏感操作确认（如权限变更、重要设置修改）
3. 结合通行密钥（Passkey）实现无密码登录

#### 依赖插件

```yaml
dependencies:
  local_auth: ^2.3.0
  # 可选：passkeys: ^2.0.0  # 支持 FIDO2/WebAuthn
```

#### 平台配置要点

**iOS**:
```xml
<!-- Info.plist -->
<key>NSFaceIDUsageDescription</key>
<string>需要面容ID验证身份</string>
```

**Android**:
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

**Windows**:
- 需要 Windows 10+ 和 TPM 2.0 支持
- 支持 Windows Hello

#### 参考资料

- [local_auth 插件文档](https://pub.dev/packages/local_auth)
- [passkeys 插件文档](https://pub.dev/packages/passkeys)
- FIDO2/WebAuthn 标准

#### 待解决问题

- [ ] 确定生物识别与现有认证系统的集成方式
- [ ] 设计 fallback 方案（生物识别失败时的处理）
- [ ] 考虑多设备同步（如 iCloud Keychain）
- [ ] 测试覆盖（需要真机测试）

---

### 🔄 Rust 端数据库迁移（sqlx-cli）

**提出日期**: 2026-05-19  
**优先级**: 高  
**状态**: 待实现

#### 功能描述

在 Rust 端集成数据库迁移机制，使用 **sqlx-cli** 管理 SQLite 数据库的 schema 变更，类似后端使用 Alembic/SQLAlchemy 的体验。

此功能是 my_app 数据存储层的基础，为后续所有功能模块（用户系统、设置、Hermes Agent 数据等）提供数据库版本管理能力。

#### 技术实现

**工具选型**: sqlx-cli（最成熟的 Rust 数据库迁移方案）

**项目结构**:
```
my_app/
├── Cargo.toml
├── migrations/              ← 迁移文件目录
│   ├── 20260519000000_initial.sql
│   ├── 20260520000000_add_settings.sql
│   └── ...
├── src/
│   ├── main.rs
│   ├── db.rs               ← 数据库逻辑
│   └── ...
└── .env                    ← DATABASE_URL=sqlite:my_app.db
```

**Rust 代码集成**:
```rust
// src/db.rs
use sqlx::{SqlitePool, migrate::MigrateDatabase};

pub async fn init_db(db_url: &str) -> Result<SqlitePool, sqlx::Error> {
    // 自动创建数据库（如果不存在）
    if !sqlx::Sqlite::database_exists(db_url).await.unwrap_or(false) {
        sqlx::Sqlite::create_database(db_url).await?;
    }
    
    // 建立连接池
    let pool = SqlitePool::connect(db_url).await?;
    
    // 执行迁移（自动读取 migrations/ 目录）
    sqlx::migrate!("./migrations")
        .run(&pool)
        .await?;
    
    println!("数据库迁移完成！");
    Ok(pool)
}
```

**常用命令**:
```bash
# 安装 sqlx-cli
cargo install sqlx-cli --no-default-features --features sqlite

# 创建新迁移
sqlx migrate add create_users_table

# 执行所有待迁移
sqlx migrate run

# 回滚一步
sqlx migrate revert

# 查看迁移状态
sqlx migrate info

# 编译时检查 SQL（需要在 .env 中配置 DATABASE_URL）
sqlx prepare
```

#### 使用场景

1. **初始化数据库 schema**（创建用户表、设置表等）
2. **版本升级时自动迁移**（新增表、新增字段）
3. **多环境管理**（开发、测试、生产环境数据库版本一致）
4. **回滚能力**（出错时可回退到上一个版本）

#### 依赖

```toml
# Cargo.toml
[dependencies]
sqlx = { version = "0.7", features = ["sqlite", "runtime-tokio-native-tls"] }

[dev-dependencies]
sqlx-cli = { version = "0.7", features = ["sqlite"] }
```

#### 待解决问题

- [ ] 确定数据库文件存储位置（应用数据目录）
- [ ] 设计初始 schema（用户、设置、各功能模块数据表）
- [ ] 考虑数据库加密（敏感数据保护）
- [ ] 迁移测试策略（如何测试迁移的正确性）

#### 参考资料

- [sqlx-cli GitHub](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli)
- [sqlx Rust 文档](https://docs.rs/sqlx/latest/sqlx/)
- 详细技术方案见 `docs/TECH_DECISIONS.md` (TDR-001)

---

### 📝 [功能名称]

**提出日期**: YYYY-MM-DD  
**优先级**: 高/中/低  
**状态**: 待评估/待实现/进行中/已完成

#### 功能描述

[详细描述]

#### 技术实现

[技术方案]

#### 使用场景

[场景说明]

#### 参考资料

[链接、文档等]

---

## 如何添加新想法

1. 复制上面的模板（`### 📝 [功能名称]` 部分）
2. 填写功能名称、日期、优先级、状态
3. 详细描述功能、技术方案、使用场景
4. 如有参考资料，添加到"参考资料"部分
5. 如有待解决问题，用 `- [ ]` 格式列出

---

**最后更新**: 2026-05-19

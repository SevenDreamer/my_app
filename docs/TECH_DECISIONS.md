# 技术决策记录 (Technical Decisions)

记录 my_app 项目的关键技术选型和决策依据。

---

## TDR-001: 数据库迁移方案选型

**日期**: 2026-05-19  
**状态**: ✅ 已决定  
**决策**: 使用 sqlx-cli + SQLite 作为数据库迁移方案

### 背景

my_app 采用 Flutter + Rust 架构，需要在 Rust 端管理本地数据库（SQLite）的 schema 迁移，类似后端使用 Alembic/SQLAlchemy 的体验。

### 评估方案

| 方案 | 类似工具 | 迁移检查 | 推荐度 | 结论 |
|------|---------|---------|--------|------|
| **sqlx-cli** | Alembic | 运行时 + 编译时 | ⭐⭐⭐⭐⭐ | ✅ **选用** |
| **refinery** | - | 编译时 | ⭐⭐⭐⭐ | 备选 |
| **diesel_cli** | Django ORM | 运行时 | ⭐⭐⭐ | 不适用 |

### 决策理由

1. **最接近 Alembic 体验** - 团队后端熟悉此模式
2. **编译时 SQL 检查** - `sqlx prepare` 可在编译时检查 SQL 语法和字段
3. **生态成熟** - Rust 社区首选，维护活跃
4. **轻量** - 适合移动端本地数据库（SQLite）
5. **迁移文件即 SQL** - 直观，易于版本控制和 Review

### 实施方案

#### 1. 安装 sqlx-cli

```bash
cargo install sqlx-cli --no-default-features --features sqlite
```

#### 2. 项目结构

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

#### 3. 迁移文件示例

```sql
-- migrations/20260519000000_create_users.sql

-- Up 迁移
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Down 回滚
DROP TABLE users;
```

#### 4. Rust 代码集成

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

#### 5. 常用命令

```bash
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

### 注意事项

1. **SQLite 的 ALTER TABLE 限制** - SQLite 不支持 DROP COLUMN（除非编译时开启）
2. **迁移文件命名** - 建议使用时间戳前缀，避免冲突
3. **Down 迁移** - 建议每个 Up 都写对应的 Down，方便回滚
4. **生产环境** - 执行迁移前务必备份数据库

### 参考资料

- [sqlx-cli GitHub](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli)
- [sqlx Rust 文档](https://docs.rs/sqlx/latest/sqlx/)
- [SQLite ALTER TABLE 文档](https://www.sqlite.org/lang_altertable.html)

---

## 模板：如何添加新的技术决策

```markdown
## TDR-XXX: [决策标题]

**日期**: YYYY-MM-DD  
**状态**: 待决定/已决定/已废弃  
**决策**: [简短描述]

### 背景
[为什么需要做这个决策]

### 评估方案
[对比不同方案的表格]

### 决策理由
[为什么选这个方案]

### 实施方案
[具体如何实施]

### 注意事项
[坑和限制]

### 参考资料
[链接、文档]
```

---

**最后更新**: 2026-05-19

# 数据库管理子应用 - 产品需求文档 (PRD)

## 1. 概述

数据库管理子应用旨在为用户提供一个统一的界面，用于管理本地和远程数据库，支持数据库连接、浏览、查询、导入导出等功能。

**目标用户**：开发者、数据库管理员、需要查看/管理数据的用户

**技术栈**：
- UI: Flutter + HeroUI Design System
- 本地数据库: SQLite, Hive
- 远程数据库: MySQL, PostgreSQL, MongoDB

---

## 2. 功能需求

### 2.1 第一阶段：连接与浏览（当前实现）

#### 2.1.1 数据库连接
- [x] 支持数据库类型选择（SQLite, MySQL, PostgreSQL, MongoDB）
- [x] 连接配置表单
  - SQLite: 文件路径选择器
  - MySQL/PostgreSQL: 主机、端口、用户名、密码、数据库名
  - MongoDB: 连接字符串
- [x] 连接测试功能
- [x] 保存连接配置（本地加密存储）
- [x] 最近连接历史

#### 2.1.2 数据库浏览
- [x] 显示所有数据库列表
- [x] 展开数据库显示所有表
- [x] 显示表结构（字段名、类型、约束）
- [x] 显示表数据预览（前 100 条）
- [x] 搜索/筛选表

---

### 2.2 第二阶段：数据操作

#### 2.2.1 数据查询
- [ ] SQL 编辑器（语法高亮）
- [ ] 查询执行与结果展示
- [ ] 查询历史记录
- [ ] 保存常用查询

#### 2.2.2 数据增删改查 (CRUD)
- [ ] 表数据浏览（分页）
- [ ] 添加新记录
- [ ] 编辑现有记录
- [ ] 删除记录（带确认）
- [ ] 批量操作

#### 2.2.3 表结构操作
- [ ] 创建新表
- [ ] 修改表结构
- [ ] 删除表（带确认）
- [ ] 导出表结构 (DDL)

---

### 2.3 第三阶段：高级功能

#### 2.3.1 数据导入/导出
- [ ] 导出为 CSV
- [ ] 导出为 JSON
- [ ] 导出为 SQL
- [ ] 从 CSV 导入
- [ ] 从 JSON 导入
- [ ] 从 SQL 导入

#### 2.3.2 数据库管理
- [ ] 创建数据库
- [ ] 删除数据库
- [ ] 数据库备份
- [ ] 数据库恢复
- [ ] 查看数据库大小

#### 2.3.3 性能优化
- [ ] 查询性能分析
- [ ] 索引管理
- [ ] 慢查询日志

---

## 3. UI/UX 设计

### 3.1 整体布局
```
┌─────────────────────────────────────────────────┐
│  AppBar: 数据库管理                    [设置] │
├──────────┬────────────────────────────────────┤
│          │                                    │
│ 连接列表  │  数据库/表结构浏览区                │
│          │                                    │
│ • SQLite │  [数据库1]                         │
│ • MySQL  │    ├─ 表1 (字段, 数据)            │
│ • PostgreSQL│  ├─ 表2                        │
│          │    └─ 表3                        │
│          │  [数据库2]                         │
│          │    └─ ...                         │
│          │                                    │
└──────────┴────────────────────────────────────┘
```

### 3.2 HeroUI 组件使用规范
- 使用 `HeroUiCard` 展示连接配置卡片
- 使用 `HeroUiButton` 作为操作按钮
- 使用 `HeroUiInput` 作为输入框
- 使用 `HeroUiTabs` 切换"结构/数据"视图
- 使用 `HeroUiTable` 展示表数据（如果包支持）
- 使用 `HeroUiTypography` 统一字体样式
- 使用 `HeroUiSwitch` / `HeroUiCheckbox` 用于设置

---

## 4. 技术实现

### 4.1 依赖包
```yaml
dependencies:
  # 数据库驱动
  sqlite3: ^2.0.0          # SQLite
  mysql_client: ^1.0.0      # MySQL
  postgres: ^3.0.0          # PostgreSQL
  mongo_dart: ^0.10.0       # MongoDB
  
  # 本地存储
  hive_flutter: ^1.1.0      # 保存连接配置
  path_provider: ^2.1.0      # 文件路径
  
  # 工具
  file_picker: ^8.0.0       # 文件选择
  csv: ^6.0.0               # CSV 处理
```

### 4.2 数据模型

```dart
// 数据库连接配置
class DbConnectionConfig {
  final String id;
  final String name;
  final DbType type;  // sqlite, mysql, postgresql, mongodb
  final String? host;
  final int? port;
  final String? username;
  final String? password;
  final String? databaseName;
  final String? filePath;  // SQLite
  final DateTime lastConnected;
}

// 数据库信息
class DatabaseInfo {
  final String name;
  final List<TableInfo> tables;
}

// 表信息
class TableInfo {
  final String name;
  final List<FieldInfo> fields;
  final int rowCount;
}

// 字段信息
class FieldInfo {
  final String name;
  final String type;
  final bool isPrimaryKey;
  final bool isNullable;
  final String? defaultValue;
}
```

### 4.3 服务层架构

```
lib/apps/database_manager/
├── models/
│   ├── db_connection_config.dart
│   ├── database_info.dart
│   ├── table_info.dart
│   └── field_info.dart
├── services/
│   ├── db_service.dart          # 抽象接口
│   ├── sqlite_service.dart      # SQLite 实现
│   ├── mysql_service.dart       # MySQL 实现
│   ├── postgresql_service.dart  # PostgreSQL 实现
│   └── connection_manager.dart  # 连接管理
├── screens/
│   ├── connection_screen.dart   # 连接配置界面
│   ├── browser_screen.dart     # 数据库浏览界面
│   └── query_screen.dart       # SQL 查询界面
└── widgets/
    ├── connection_list.dart
    ├── database_tree.dart
    ├── table_structure.dart
    └── data_table.dart
```

---

## 5. 开发计划

### Phase 1: MVP（当前阶段）
- [x] 创建子应用入口
- [ ] 实现连接配置界面
- [ ] 实现 SQLite 连接
- [ ] 显示数据库列表
- [ ] 显示表结构
- [ ] 显示表数据预览

### Phase 2: 扩展数据库支持
- [ ] 实现 MySQL 连接
- [ ] 实现 PostgreSQL 连接
- [ ] 实现 MongoDB 连接
- [ ] 连接配置保存/加载

### Phase 3: 数据操作
- [ ] SQL 编辑器
- [ ] 数据增删改查
- [ ] 表结构编辑

### Phase 4: 导入/导出
- [ ] 导出 CSV/JSON/SQL
- [ ] 导入 CSV/JSON/SQL
- [ ] 数据库备份/恢复

---

## 6. 测试计划

- [ ] 单元测试：数据模型、服务层
- [ ] 集成测试：数据库连接
- [ ] UI 测试：关键用户流程

---

## 7. 参考设计

- **DBeaver**: 通用数据库客户端
- **phpMyAdmin**: MySQL 管理工具
- **MongoDB Compass**: MongoDB GUI
- **TablePlus**: macOS 数据库工具（设计参考）

---

## 8. 备注

- 前期只实现连接和浏览功能
- 密码需要加密存储（使用 `flutter_secure_storage`）
- 大数据表需要分页加载
- SQL 执行需要防止注入攻击

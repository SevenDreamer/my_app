# shadcn_flutter 使用指南

> **包名**: `shadcn_flutter`  
> **版本**: `^0.0.52`  
> **作者**: Thito Yalasatria Sunarya  
> **灵感来源**: [shadcn/ui](https://ui.shadcn.com/)  
> **License**: BSD-3-Clause  
> **支持平台**: Android, iOS, Linux, macOS, Windows, Web

---

## 📦 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  shadcn_flutter: ^0.0.52
```

然后运行：

```bash
flutter pub get
```

---

## 🎨 核心特性

| 特性 | 说明 |
|------|------|
| **84+ 组件** | 从基础按钮到复杂数据表格 |
| **独立生态系统** | 不依赖 Material 或 Cupertino，可选择性互操作 |
| **shadcn/ui 设计令牌** | 提供现成的 New York 主题 |
| **渐进式迁移** | 可在现有 MaterialApp 中混用 |
| **全平台支持** | Android、iOS、Web、macOS、Windows、Linux |
| **Tree Shakable** | 按需导入，只引入需要的组件 |
| **LLM 友好** | 提供 `llms-full.txt` 文件，方便 AI 辅助开发 |

---

## 🚀 快速开始

### 1. 基本使用（独立使用）

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'My App',
      theme: ThemeData(
        colorScheme: LegacyColorSchemes.darkZinc(),
        radius: 0.7,
      ),
      home: HomePage(),
    );
  }
}
```

### 2. 在现有 MaterialApp 中混用

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

// 可以直接在 MaterialApp 中使用 shadcn_flutter 组件
// 无需一次性全部替换
```

---

## 🧩 完整组件列表

### 📝 Form（表单组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `TextField` | 文本输入框 | `TextField(controller: ...)` |
| `TextArea` | 多行文本输入框 | `TextArea(controller: ...)` |
| `Select` | 下拉选择 | `Select(items: [...])` |
| `MultipleChoice` | 多选 | `MultipleChoice(items: [...])` |
| `Checkbox` | 复选框 | `Checkbox(value: true, onChanged: ...)` |
| `RadioGroup` | 单选组 | `RadioGroup(items: [...])` |
| `Switch` | 开关 | `Switch(value: true, onChanged: ...)` |
| `Slider` | 滑块 | `Slider(value: 0.5, onChanged: ...)` |
| `StarRating` | 星级评分 | `StarRating(value: 3, onChanged: ...)` |
| `DatePicker` | 日期选择器 | `DatePicker()` |
| `TimePicker` | 时间选择器 | `TimePicker()` |
| `Autocomplete` | 自动补全 | `Autocomplete(options: [...])` |
| `ChipInput` | Chip 输入 | `ChipInput()` |
| `InputOTP` | OTP 输入 | `InputOTP(length: 6)` |
| `PhoneInput` | 电话输入 | `PhoneInput()` |
| `Form` | 表单容器 | `Form(child: ...)` |
| `FormField` | 表单项 | `FormField(validator: ...)` |
| `Validated` | 验证容器 | `Validated(child: ...)` |
| `ColorPicker` | 颜色选择器 | `ColorPicker()` |
| `ItemPicker` | 项目选择器 | `ItemPicker()` |

#### 示例：表单使用

```dart
Form(
  child: Column(
    children: [
      TextField(
        label: Text('用户名'),
        hintText: '请输入用户名',
      ),
      TextField(
        label: Text('密码'),
        obscureText: true,
      ),
      PrimaryButton(
        onPressed: () {
          // 提交表单
        },
        child: Text('提交'),
      ),
    ],
  ),
)
```

---

### 📊 Display（数据展示组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `Avatar` | 头像 | `Avatar(child: Text('AB'))` |
| `Badge` | 徽章 | `Badge(primary: true, child: ...)` |
| `Calendar` | 日历 | `Calendar()` |
| `Carousel` | 轮播 | `Carousel(children: [...])` |
| `Chip` | Chip 标签 | `Chip(label: Text('标签'))` |
| `CircularProgressIndicator` | 圆形进度条 | `CircularProgressIndicator()` |
| `LinearProgressIndicator` | 线性进度条 | `LinearProgressIndicator()` |
| `CodeSnippet` | 代码片段 | `CodeSnippet(code: '...')` |
| `Divider` | 分割线 | `Divider()` |
| `DotIndicator` | 点指示器 | `DotIndicator()` |
| `NumberTicker` | 数字滚动 | `NumberTicker(value: 100)` |
| `Progress` | 进度 | `Progress(value: 0.5)` |
| `Skeleton` | 骨架屏 | `Skeleton()` |
| `Chat` | 聊天气泡 | `Chat(messages: [...])` |

#### 示例：Avatar 和 Badge

```dart
Avatar(
  size: 40,
  child: Text('AB'),
  // 或者使用图片
  // src: 'https://example.com/avatar.png',
)

Badge.primary(
  child: Text('新'),
)
```

---

### 🎯 Control（控制组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `PrimaryButton` | 主要按钮 | `PrimaryButton(child: Text('按钮'))` |
| `SecondaryButton` | 次要按钮 | `SecondaryButton(...)` |
| `OutlineButton` | 轮廓按钮 | `OutlineButton(...)` |
| `GhostButton` | 幽灵按钮 | `GhostButton(...)` |
| `LinkButton` | 链接按钮 | `LinkButton(...)` |
| `DestructiveButton` | 危险按钮 | `DestructiveButton(...)` |
| `IconButton` | 图标按钮 | `IconButton(icon: Icons.add)` |
| `Clickable` | 可点击区域 | `Clickable(onTap: () {}, child: ...)` |
| `Command` | 命令面板 | `Command(...)` |

#### 示例：按钮使用

```dart
PrimaryButton(
  onPressed: () {
    print(' clicked');
  },
  density: ButtonDensity.comfortable,
  child: Text('主要按钮'),
)

GhostButton(
  onPressed: () {},
  child: Icon(Icons.menu),
)
```

---

### 📐 Layout（布局组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `Scaffold` | 页面脚手架 | `Scaffold(headers: [...], child: ...)` |
| `AppBar` | 应用栏 | `AppBar(title: Text('标题'))` |
| `Card` | 卡片 | `Card(child: ...)` |
| `CardImage` | 图片卡片 | `CardImage(...)` |
| `Alert` | 警告提示 | `Alert(title: ..., content: ...)` |
| `Accordion` | 手风琴 | `Accordion(items: [...])` |
| `Collapsible` | 可折叠 | `Collapsible(...)` |
| `Breadcrumb` | 面包屑 | `Breadcrumb(items: [...])` |
| `Table` | 表格 | `Table(data: [...])` |
| `Timeline` | 时间线 | `Timeline(items: [...])` |
| `Stepper` | 步骤条 | `Stepper(steps: [...])` |
| `Resizable` | 可调整大小 | `Resizable(...)` |
| `Divider` | 分割线 | `Divider()` |
| `OutlinedContainer` | 边框容器 | `OutlinedContainer(...)` |
| `Window` | 窗口 | `Window(...)` |

#### 示例：Scaffold 和 AppBar

```dart
Scaffold(
  headers: [
    AppBar(
      title: Text('我的应用'),
      trailing: [
        IconButton(icon: Icons.settings),
      ],
    ),
  ],
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('页面内容'),
  ),
)
```

---

### 🧭 Navigation（导航组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `NavigationBar` | 导航栏 | `NavigationBar(children: [...])` |
| `NavigationRail` | 导航侧栏 | `NavigationRail(...)` |
| `Tabs` | 标签页 | `Tabs(items: [...])` |
| `TabContainer` | 标签容器 | `TabContainer(...)` |
| `TabList` | 标签列表 | `TabList(...)` |
| `TabPane` | 标签面板 | `TabPane(...)` |
| `Pagination` | 分页 | `Pagination(...)` |
| `Steps` | 步骤 | `Steps(...)` |

#### 示例：Tabs 使用

```dart
Tabs(
  children: [
    TabPane(
      label: Text('标签页 1'),
      child: Text('内容 1'),
    ),
    TabPane(
      label: Text('标签页 2'),
      child: Text('内容 2'),
    ),
  ],
)
```

---

### 🖼️ Overlay（覆盖层组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `Dialog` | 对话框 | `Dialog(title: ..., content: ...)` |
| `AlertDialog` | 警告对话框 | `AlertDialog(...)` |
| `Drawer` | 抽屉 | `Drawer(...)` |
| `Popover` | 弹出框 | `Popover(...)` |
| `Tooltip` | 工具提示 | `Tooltip(message: '提示', child: ...)` |
| `Toast` | 吐司通知 | `Toast(...)` |
| `HoverCard` | 悬停卡片 | `HoverCard(...)` |
| `Overlay` | 覆盖层 | `Overlay(...)` |

#### 示例：Dialog 使用

```dart
// 显示对话框
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('确认'),
    content: Text('确定要删除吗？'),
    actions: [
      SecondaryButton(
        onPressed: () => Navigator.pop(context),
        child: Text('取消'),
      ),
      DestructiveButton(
        onPressed: () {
          // 删除操作
          Navigator.pop(context);
        },
        child: Text('删除'),
      ),
    ],
  ),
);
```

---

### 📋 Menu（菜单组件）

| 组件 | 说明 | 基本用法 |
|------|------|----------|
| `Menu` | 菜单 | `Menu(items: [...])` |
| `MenuItem` | 菜单项 | `MenuItem(child: Text('菜单项'))` |
| `MenuBar` | 菜单栏 | `MenuBar(items: [...])` |
| `ContextMenu` | 右键菜单 | `ContextMenu(...)` |
| `DropdownMenu` | 下拉菜单 | `DropdownMenu(items: [...])` |
| `NavigationMenu` | 导航菜单 | `NavigationMenu(...)` |
| `Popup` | 弹出层 | `Popup(...)` |

---

### 🎨 Theme（主题）

#### 主题配置

```dart
ShadcnApp(
  theme: ThemeData(
    colorScheme: LegacyColorSchemes.darkZinc(), // 或 lightZinc, darkRose 等
    radius: 0.7, // 圆角大小
  ),
  // 或者使用生成的主题
  // theme: LegacyGeneratedThemes.darkZinc(),
)
```

#### 可用主题

| 主题名称 | 说明 |
|---------|------|
| `darkZinc` / `lightZinc` | Zinc 色系 |
| `darkRose` / `lightRose` | Rose 色系 |
| `darkBlue` / `lightBlue` | Blue 色系 |
| `darkGreen` / `lightGreen` | Green 色系 |
| `darkOrange` / `lightOrange` | Orange 色系 |
| `darkRed` / `lightRed` | Red 色系 |
| `darkSlate` / `lightSlate` | Slate 色系 |
| `darkStone` / `lightStone` | Stone 色系 |

---

### 🎨 Icons（图标）

shadcn_flutter 内置了三套图标库：

| 图标库 | 说明 | 使用示例 |
|--------|------|----------|
| `LucideIcons` | Lucide 图标（默认） | `Icon(LucideIcons.heart)` |
| `BootstrapIcons` | Bootstrap 图标 | `Icon(BootstrapIcons.heart)` |
| `RadixIcons` | Radix 图标 | `Icon(RadixIcons.heart)` |

```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

Icon(LucideIcons.search)
Icon(BootstrapIcons.search)
Icon(RadixIcons.search)
```

---

### 📝 Typography（排版）

shadcn_flutter 提供了文本样式扩展：

```dart
Text('标题').h1()
Text('副标题').h2()
Text('正文').p()
Text('小文本').small()
Text('代码').code()
```

---

## 🔄 与 heroui_design_system 对比

| 特性 | shadcn_flutter | heroui_design_system |
|------|----------------|----------------------|
| **组件数量** | 84+ | ~30 |
| **设计系统** | shadcn/ui | HeroUI |
| **依赖 Material** | 可选 | 依赖 |
| **主题系统** | 完整 | 基础 |
| **表单组件** | 非常丰富 | 基础 |
| **数据展示** | 丰富（Table, Calendar 等） | 基础 |
| **维护状态** | 活跃 | 一般 |

---

## 💡 实用技巧

### 1. 使用 Controlled 组件进行表单绑定

```dart
// 控制器方式
final _emailController = TextEditingController();

TextField(
  controller: _emailController,
  label: Text('邮箱'),
  hintText: '请输入邮箱',
)

// 或者使用 Controlled 组件
ControlledTextField(
  control: FormControl<String>(),
  label: Text('邮箱'),
)
```

### 2. 响应式布局

```dart
MediaQueryVisibility(
  visible: (context) {
    final size = MediaQuery.of(context).size;
    return size.width > 600; // 仅在宽屏显示
  },
  child: Text('宽屏内容'),
)
```

### 3. 使用 Skeleton 加载占位

```dart
Skeleton(
  enabled: _isLoading,
  child: _isLoading ? Container() : ActualContent(),
)
```

---

## ⚠️ 注意事项

1. **不要同时导入 Material 和 shadcn_flutter 的冲突类**
   ```dart
   // 错误：会冲突
   import 'package:flutter/material.dart';
   import 'package:shadcn_flutter/shadcn_flutter.dart';
   
   // 正确：hide 冲突类
   import 'package:flutter/material.dart' hide Form, Table;
   import 'package:shadcn_flutter/shadcn_flutter.dart';
   ```

2. **按钮需要使用 `onPressed` 而非 `onTap`**

3. **主题配置需要在 `ShadcnApp` 中设置**

---

## 📚 参考资源

- **pub.dev**: https://pub.dev/packages/shadcn_flutter
- **GitHub**: https://github.com/sunarya-thito/shadcn_flutter
- **shadcn/ui 官方**: https://ui.shadcn.com/
- **示例项目**: 查看包内的 example 目录

---

## 📝 总结

`shadcn_flutter` 是一个功能非常完整的 Flutter UI 库，适合需要快速构建现代化 UI 的项目。它的优势在于：

1. **组件丰富** - 84+ 组件覆盖大部分场景
2. **设计优美** - 基于 shadcn/ui，视觉效果出色
3. **灵活集成** - 可与现有 MaterialApp 混用
4. **主题完善** - 提供多种预设主题

如果你的项目需要丰富的表单组件、数据展示组件，或者想要 shadcn/ui 的视觉效果，`shadcn_flutter` 是一个非常好的选择。

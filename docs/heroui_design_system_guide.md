# HeroUI Design System 组件文档

> 包名：`heroui_design_system`
> 来源：`https://github.com/tereshin/the-blank.git`（`packages/heroui_design_system`）
> 更新时间：2026-05-18

---

## 目录

1. [安装方式](#1-安装方式)
2. [导入方式](#2-导入方式)
3. [设计令牌](#3-设计令牌)
4. [组件列表](#4-组件列表)
   - [Layout 布局](#layout-布局)
   - [Typography 排版](#typography-排版)
   - [Buttons 按钮](#buttons-按钮)
   - [Cards 卡片](#cards-卡片)
   - [Navigation 导航](#navigation-导航)
   - [Feedback 反馈](#feedback-反馈)
   - [Controls 控件](#controls-控件)
   - [Forms 表单](#forms-表单)
   - [Overlays 覆盖层](#overlays-覆盖层)
   - [Pickers 选择器](#pickers-选择器)
   - [Collections 集合](#collections-集合)
   - [Media 媒体](#media-媒体)
   - [Effects 效果](#effects-效果)
   - [Icons 图标](#icons-图标)
5. [注意事项](#5-注意事项)

---

## 1. 安装方式

```yaml
dependencies:
  heroui_design_system:
    git:
      url: https://github.com/tereshin/the-blank.git
      path: packages/heroui_design_system
```

## 2. 导入方式

```dart
import 'package:heroui_design_system/design_system.dart';
```

> **注意**：该包不导出 Flutter 基础类（`Widget`、`StatelessWidget`、`BuildContext`、`Icon` 等），
> 使用 `HeroUi*` 组件时仍需导入 `package:flutter/material.dart`。

---

## 3. 设计令牌

### HeroUiTypography（排版）

| 令牌 | 用途 | 字号 | 字重 | 行高 |
|-------|------|------|------|------|
| `heading1` | 一级标题 | 46.8 | w800 | 1.12 |
| `heading2` | 二级标题 | 31.2 | w700 | 1.34 |
| `heading3` | 三级标题 | 26 | w600 | 1.6 |
| `heading4` | 四级标题 | 20.8 | w600 | 1.5 |
| `bodyBase` | 基础正文 | 20.8 | w400 | 1.5 |
| `bodyBaseMedium` | 中等正文 | 20.8 | w500 | 1.5 |
| `bodySm` | 小号正文 | 18.2 | w400 | 1.43 |
| `bodySmMedium` | 小号中等正文 | 18.2 | w500 | 1.43 |
| `bodyXs` | 超小正文 | 16 | w400 | 1.34 |
| `bodyXsMedium` | 超小中等正文 | 16 | w500 | 1.34 |
| `navLabel` | 导航标签 | 10 | w500 | 1.34 |
| `linkBase` | 基础链接 | 20.8 | w500 | 1.25 |
| `linkSm` | 小号链接 | 18.2 | w500 | 18/14 |
| `textFieldBase` | 基础输入框文字 | 20.8 | w400 | 1.25 |
| `textFieldSm` | 小号输入框文字 | 18.2 | w400 | 20/14 |
| `textOTPFieldBase` | OTP 输入框文字 | 20.8 | w600 | 1.25 |
| `buttonBase` | 按钮文字 | 18.2 | w500 | 20/14 |

还提供了 `HeroUiTypography.materialTextTheme`，可直接用于 `ThemeData(textTheme:)`。

### HeroUiRadius（圆角）

```dart
HeroUiRadius.none      // 0
HeroUiRadius.sm        // 4
HeroUiRadius.md        // 8
HeroUiRadius.lg        // 12
HeroUiRadius.xl        // 16
HeroUiRadius.twoXl     // 20
HeroUiRadius.threeXl   // 24
HeroUiRadius.fourXl    // 32
HeroUiRadius.full      // 9999 (圆形)
HeroUiRadius.borderCircular(double)  // 便捷方法
```

---

## 4. 组件列表

---

### Layout 布局

#### HeroUiShell

类似 `Scaffold`，但 `appBar` 和 `bottomNavigationBar` **浮动**在内容上方（iOS 风格），带圆角和阴影。

```dart
HeroUiShell({
  required Widget body,
  PreferredSizeWidget? appBar,
  Widget? bottomNavigationBar,
  Color? backgroundColor,
  bool resizeToAvoidBottomInset = true,
  double floatingMargin = 12,     // 浮动边距
  double barBorderRadius = 20,     // 浮动栏圆角
  double barElevation = 3,        // 阴影高度
})
```

**使用建议**：用 `HeroUiShell` 替代 `Scaffold`，实现统一的 iOS 风格外壳。

#### HeroUiSurface

表面容器，支持多种背景变体。

```dart
enum HeroUiSurfaceVariant { defaultVariant, subtle, strong }
```

---

### Typography 排版

直接使用 `HeroUiTypography` 的静态属性：

```dart
Text('Hello', style: HeroUiTypography.heading2)
Text('Description', style: HeroUiTypography.bodySm)
```

---

### Buttons 按钮

#### HeroUiButton

```dart
HeroUiButton({
  required String label,
  required VoidCallback? onPressed,
  HeroUiButtonVariant variant = HeroUiButtonVariant.primary,
  HeroUiButtonSize size = HeroUiButtonSize.md,
  HeroUiButtonVisualState state = HeroUiButtonVisualState.defaultState,
  Widget? leading,
  Widget? trailing,
  bool iconOnly = false,        // 纯图标模式
  BorderRadiusGeometry? borderRadiusOverride,
  bool expand = false,           // 是否撑满宽度
})
```

**Variant 枚举**：
- `primary` - 主要按钮（蓝色填充）
- `secondary` - 次要按钮（灰色填充）
- `tertiary` - 第三按钮（无填充，带边框）
- `danger` - 危险按钮（红色）
- `success` - 成功按钮（绿色）
- `warning` - 警告按钮（橙色）

**Size 枚举**：
- `sm` - 小号（高度 32）
- `md` - 中号（高度 40）
- `lg` - 大号（高度 48）

#### HeroUiButtonGroup

按钮组，横向排列一组 `HeroUiButton`。

#### HeroUiCloseButton

关闭按钮（X 图标）。

#### HeroUiToggleButtons

切换按钮组（类似 SegmentedButton）。

#### HeroUiStarReview

星级评分组件。

---

### Cards 卡片

#### HeroUiCard

```dart
HeroUiCard({
  Widget? header,           // 使用 HeroUiCardHeader
  Widget? body,             // 卡片主体内容
  Widget? footer,           // 使用 HeroUiCardFooter
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  double sectionGap = 12,   // header/body/footer 之间的间距
  double borderRadius = 24,
  bool showShadow = true,
  VoidCallback? onTap,      // 可点击卡片
  Color? backgroundColor,
  HeroUiSurfaceVariant surfaceVariant = HeroUiSurfaceVariant.defaultVariant,
  Color? borderColor,
})
```

#### HeroUiCardHeader

```dart
HeroUiCardHeader({
  String? tagline,       // 标签行（小字，置顶）
  String? title,         // 标题
  String? description,   // 描述文字
  Widget? trailing,      // 右侧 trailing widget
})
```

#### HeroUiCardFooter

卡片底部容器（仅包裹 child）。

#### HeroUiCardMedia

卡片媒体内容（图片/视频），自动裁剪圆角。

```dart
HeroUiCardMedia({
  required Widget child,
  double? width,
  double? height,
  double borderRadius = 12,
})
```

---

### Navigation 导航

#### HeroUiTabs

标签页组件，功能丰富。

```dart
HeroUiTabs({
  required List<HeroUiTabItem> tabs,
  int initialIndex = 0,
  HeroUiTabsVariant variant = HeroUiTabsVariant.primary,
  HeroUiTabsBehavior behavior = HeroUiTabsBehavior.hug,
  HeroUiTabContentOrientation tabContentOrientation = HeroUiTabContentOrientation.horizontal,
  bool showScrollShadow = true,
  bool showScrollButtons = false,
  List<bool>? showOptions,   // 控制每个 tab 是否可见
  bool showPanel = true,      // 是否显示 tab 内容面板
  double? panelHeight,        // 面板固定高度（null = 自适应）
  EdgeInsetsGeometry panelPadding = const EdgeInsets.all(16),
  bool enableSwipeSelection = true,  // 长按拖拽选择
  ValueChanged<int>? onChanged,
})
```

**HeroUiTabItem**：
```dart
HeroUiTabItem({
  required String label,
  required Widget child,    // tab 对应的内容 widget
  Widget? leading,          // 前置图标
  Widget? trailing,         // 后置图标
  bool isDisabled = false,
})
```

**Variant**：
- `primary` - 选中项有填充背景（类似 iOS 分段控制器）
- `secondary` - 选中项仅有下划线指示

**Behavior**：
- `hug` - 标签栏宽度跟随内容（可横向滚动）
- `fill` - 标签栏撑满宽度（等分）

#### HeroUiNavigation

垂直导航（基于 `HeroUiTabs`，`tabContentOrientation: vertical`）。

```dart
HeroUiNavigation({
  required List<HeroUiTabItem> tabs,
  int initialIndex = 0,
  HeroUiTabsVariant variant = HeroUiTabsVariant.primary,
  HeroUiTabsBehavior behavior = HeroUiTabsBehavior.hug,
  // ... 其他参数同 HeroUiTabs
})
```

> **重要**：`HeroUiNavigation` 的 `leading` 图标会显示在上方，`label` 在下方（垂直布局），
> 字号使用 `HeroUiTypography.navLabel`（10px），适合侧边栏导航。

#### HeroUiBreadcrumbs

面包屑导航。

#### HeroUiLink

内联链接组件（使用 `HeroUiTypography.linkBase / linkSm` 样式）。

#### HeroUiPagination

分页组件。

#### HeroUiToolbar

工具栏组件。

---

### Feedback 反馈

#### HeroUiSpinner

圆形加载指示器（旋转渐变环）。

```dart
HeroUiSpinner({
  HeroUiSpinnerSize size = HeroUiSpinnerSize.md,
  HeroUiComponentType type = HeroUiComponentType.accent,
})
```

**Size**：`sm`（21px）、`md`（31px）、`lg`（42px）、`xl`（52px）

**Type**（颜色）：`defaultType`、`accent`（蓝）、`success`（绿）、`warning`（橙）、`danger`（红）

#### HeroUiProgressBar

水平进度条。

```dart
HeroUiProgressBar({
  required double value,      // 0.0–1.0
  String? label,              // 左侧标签
  String? valueLabel,         // 右侧数值标签
  HeroUiProgressBarSize size = HeroUiProgressBarSize.md,
  HeroUiComponentType type = HeroUiComponentType.accent,
  bool isIndeterminate = false,  // 不确定模式（动画闪烁）
})
```

**Size**：`sm`（轨道高 5px）、`md`（10px）、`lg`（16px）

#### HeroUiProgressCircle

圆形进度环。

```dart
HeroUiProgressCircle({
  required double value,      // 0.0–1.0
  String? label,
  HeroUiProgressCircleSize size = HeroUiProgressCircleSize.md,
  HeroUiComponentType type = HeroUiComponentType.accent,
})
```

**Size**：`sm`（26px）、`md`（36px）、`lg`（47px）

#### HeroUiAlert

内联警告横幅（类似 Banner）。

```dart
HeroUiAlert({
  required String title,
  String? description,
  HeroUiComponentType type = HeroUiComponentType.defaultType,
  String? actionLabel,        // 操作按钮文字
  VoidCallback? onAction,     // 操作回调
  VoidCallback? onClose,     // 关闭回调（显示关闭 X）
})
```

**Type 对应的图标**：
- `defaultType` / `accent` → `info_outline_rounded`
- `success` → `check_circle_outline_rounded`
- `warning` → `warning_amber_rounded`
- `danger` → `error_outline_rounded`

#### HeroUiToast / HeroUiToastService

轻量级临时通知（类似 SnackBar）。

```dart
HeroUiToastService.show(
  context,
  message: '保存成功',
  description: '数据已同步到云端',
  type: HeroUiComponentType.success,
  actionLabel: '撤销',
  onAction: () { /* 撤销操作 */ },
  duration: Duration(seconds: 3),
);

// 手动关闭
HeroUiToastService.dismiss();
```

---

### Controls 控件

#### HeroUiCheckbox

复选框（完整版，带 label + description）。

```dart
HeroUiCheckbox({
  bool? value,              // null = indeterminate（中间状态）
  String? label,
  String? description,
  String? errorMessage,      // isInvalid=true 时显示
  bool isDisabled = false,
  bool isInvalid = false,
  HeroUiCheckboxVariant variant = HeroUiCheckboxVariant.primary,
  ValueChanged<bool>? onChanged,  // 返回下一个 bool 值
})
```

#### HeroUiCheckboxGroup

复选框组（多选）。

```dart
HeroUiCheckboxGroup({
  required List<HeroUiCheckboxGroupItem> items,
  required Set<String> values,    // 当前选中的 value 集合
  required ValueChanged<Set<String>> onChanged,
  String? label,
  String? description,
  String? errorMessage,
  bool isDisabled = false,
  bool isInvalid = false,
  HeroUiCheckboxGroupOrientation orientation = HeroUiCheckboxGroupOrientation.vertical,
  HeroUiCheckboxVariant variant = HeroUiCheckboxVariant.primary,
})
```

#### HeroUiRadio

单选框（完整版，带 label）。

#### HeroUiSlider

滑块控件。

#### HeroUiSwitch

开关控件。

---

### Forms 表单

#### HeroUiInput

输入框外壳（带 label、description、errorMessage、prefix/suffix 图标）。

#### HeroUiTextField

文本输入框（基于 `HeroUiInput`）。

#### HeroUiInputGroup

输入框组（多个输入框横向排列）。

#### HeroUiNumberField

数字输入框（带加减按钮）。

#### HeroUiSearchField

搜索输入框（自带搜索图标）。

#### HeroUiInputOTP

OTP 验证码输入框（多位数字输入）。

---

### Overlays 覆盖层

#### HeroUiTooltip

工具提示（长按/悬停显示）。

#### HeroUiPopover

弹出面板（点击触发，显示在目标附近）。

#### HeroUiDropdown

下拉面板（自定义 overlay 实现的下拉）。

#### HeroUiModal

模态对话框（全屏遮罩 + 居中面板）。

#### HeroUiAlertDialog

确认对话框（带标题、内容、确认/取消按钮）。

#### HeroUiDrawer

侧边抽屉面板。

---

### Pickers 选择器

#### HeroUiSelect<T>

下拉选择器（自定义 overlay，不依赖 `DropdownButton`）。

```dart
HeroUiSelect<String>(   // T 为 value 的类型
  items: [
    HeroUiPickerItem(value: 'apple', label: 'Apple'),
    HeroUiPickerItem(value: 'banana', label: 'Banana', leading: Icon(Icons.food_bank)),
  ],
  value: _selectedValue,
  onChanged: (v) => setState(() => _selectedValue = v),
  label: '水果',
  placeholder: '选择一个水果',
  requiredField: true,
  variant: HeroUiInputVariant.primary,
  enabled: true,
  errorText: null,
  maxListHeight: 312,
)
```

#### HeroUiComboBox

组合框（可输入 + 下拉选择）。

#### HeroUiCalendar

日历日期选择器。

#### HeroUiColorPicker

颜色选择器。

---

### Collections 集合

#### HeroUiAccordion

手风琴（可折叠的展开面板）。

#### HeroUiListBox

列表框（类似 Select，但显示在页面内而非 overlay）。

#### HeroUiMenuCard

菜单卡片（带图标的菜单项列表）。

#### HeroUiTable

数据表格。

#### HeroUiTagGroup

标签组（多个可删除标签）。

---

### Media 媒体

#### HeroUiCarousel

轮播组件（图片/内容轮播）。

---

### Effects 效果

视觉效果组件（如 `HeroUiGlow`、`HeroUiShimmer` 等，具体查看源码）。

---

### Icons 图标

#### HeroUiIcon

SVG 图标组件（包内预置了 icons 目录）。

```dart
HeroUiIcon(HeroUiIconManifest.check, size: 24, color: Colors.blue)
```

`HeroUiIconManifest` 是所有可用图标名称的枚举类，位于 `icons/heroui_icon.dart`。

> **注意**：也可以直接使用 `lucide_flutter` 包获取更多图标。

---

## 5. 注意事项

### ⚠️ 不导出 Flutter 基础类

`heroui_design_system` **不导出** `Widget`、`StatelessWidget`、`State`、`BuildContext`、`Icon`、`Colors` 等 Flutter 基础类。

**正确写法**：
```dart
import 'package:flutter/material.dart';
import 'package:heroui_design_system/design_system.dart';

// 使用 Flutter 基础类
Icon(Icons.home, size: 24)

// 使用 HeroUI 组件
HeroUiButton(label: 'Click', onPressed: () {})
```

### ⚠️ 无 BottomNavigationBar 组件

`heroui_design_system` **没有提供**底部导航栏组件。

**解决方案**：
1. 使用 `HeroUiShell` + 自定义底部导航 Row
2. 或使用 Material `NavigationBar` 并包裹在 `HeroUiShell(bottomNavigationBar:)` 中

### ⚠️ 无 AppBar 组件

`heroui_design_system` **没有提供** AppBar 组件。

**解决方案**：
1. 使用普通 `AppBar` 传入 `HeroUiShell(appBar:)`
2. 或自定义 `PreferredSizeWidget`

### ⚠️ 无 SegmentedButton 替代

如果需要分段按钮（类似 iOS 分段控制器），可使用 `HeroUiTabs(variant: primary, behavior: fill)` 模拟。

---

## 6. 完整使用示例

```dart
import 'package:flutter/material.dart';
import 'package:heroui_design_system/design_system.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HeroUiShell(
      appBar: AppBar(
        title: Text('My App', style: HeroUiTypography.heading4),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: HeroUiCard(
        header: HeroUiCardHeader(
          tagline: 'RECOMMENDED',
          title: 'Getting Started',
          description: 'Follow these steps to set up your project.',
        ),
        body: Text(
          'This is the card body content.',
          style: HeroUiTypography.bodySm,
        ),
        footer: HeroUiCardFooter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              HeroUiButton(
                label: 'Cancel',
                variant: HeroUiButtonVariant.tertiary,
                onPressed: () {},
              ),
              SizedBox(width: 8),
              HeroUiButton(
                label: 'Continue',
                variant: HeroUiButtonVariant.primary,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _NavItem(icon: LucideIcons.home, label: 'Home', selected: true),
        _NavItem(icon: LucideIcons.search, label: 'Search'),
        _NavItem(icon: LucideIcons.settings, label: 'Settings'),
      ],
    );
  }
}
```

---

## 7. 与 Material 组件对照表

| Material 组件 | HeroUI 替代方案 |
|--------------|-----------------|
| `Scaffold` | `HeroUiShell` |
| `AppBar` | 仍需用 `AppBar`（传入 `HeroUiShell.appBar`） |
| `NavigationBar` / `BottomNavigationBar` | 自定义 Row + `HeroUiShell(bottomNavigationBar:)` |
| `ElevatedButton` | `HeroUiButton(variant: primary)` |
| `OutlinedButton` | `HeroUiButton(variant: tertiary)` |
| `TextButton` | `HeroUiButton(variant: secondary)` |
| `Card` | `HeroUiCard` |
| `TabBar` + `TabBarView` | `HeroUiTabs` |
| `SegmentedButton` | `HeroUiTabs(variant: primary, behavior: fill)` |
| `Checkbox` | `HeroUiCheckbox` |
| `Radio` | `HeroUiRadio` |
| `Switch` | `HeroUiSwitch` |
| `TextField` | `HeroUiTextField` |
| `DropdownButton` | `HeroUiSelect` |
| `LinearProgressIndicator` | `HeroUiProgressBar` |
| `CircularProgressIndicator` | `HeroUiSpinner` 或 `HeroUiProgressCircle` |
| `SnackBar` | `HeroUiToastService.show()` |
| `AlertDialog` | `HeroUiAlertDialog` |
| `Banner` | `HeroUiAlert` |
| `Tooltip` | `HeroUiTooltip` |
| `Drawer` | `HeroUiDrawer` |
| `DataTable` | `HeroUiTable` |
| `Chip` | `HeroUiTagGroup` 中的单个 tag |

---

*文档生成时间：2026-05-18*
*基于 `the-blank` main 分支 `packages/heroui_design_system`*

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/core/theme/app_theme_mode.dart';
import 'package:my_app/core/theme/app_theme.dart';

/// 主题状态管理
///
/// 使用 ValueNotifier 在 widget 树中共享主题状态，支持动态切换
class AppThemeScope extends StatefulWidget {
  final Widget child;

  const AppThemeScope({
    required this.child,
    super.key,
  });

  /// 获取最近的 AppThemeScope 状态
  static AppThemeScopeState of(BuildContext context) {
    return context.findAncestorStateOfType<AppThemeScopeState>()!;
  }

  @override
  State<AppThemeScope> createState() => AppThemeScopeState();
}

class AppThemeScopeState extends State<AppThemeScope>
    with WidgetsBindingObserver {
  static const _key = 'theme_mode';
  final ValueNotifier<AppThemeMode> _notifier =
      ValueNotifier(AppThemeMode.system);

  AppThemeMode get mode => _notifier.value;
  ValueNotifier<AppThemeMode> get notifier => _notifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
  }

  @override
  void didChangePlatformBrightness() {
    if (_notifier.value == AppThemeMode.system) {
      setState(() {});
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_key);
    if (modeString != null) {
      _notifier.value = AppThemeMode.values.firstWhere(
        (m) => m.name == modeString,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    _notifier.value = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  ShadThemeData buildTheme() {
    final isDark = mode == AppThemeMode.dark ||
        (mode == AppThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    // 使用 Obsidian 风格主题
    return isDark ? buildObsidianDarkTheme() : buildObsidianLightTheme();
  }

  /// 构建暗黑主题（用于 ShadApp.darkTheme 参数）
  ShadThemeData buildDarkTheme() {
    return buildObsidianDarkTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

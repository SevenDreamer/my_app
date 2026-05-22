// ==================== 应用主题模式枚举 ====================
enum AppThemeMode {
  light('浅色模式'),
  dark('深色模式'),
  system('跟随系统');

  final String displayName;

  const AppThemeMode(this.displayName);
}

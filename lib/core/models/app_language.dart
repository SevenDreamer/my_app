/// 支持的语言枚举
enum AppLanguage {
  zh('zh', '简体中文'),
  en('en', 'English');

  final String code;
  final String displayName;

  const AppLanguage(this.code, this.displayName);

  /// 从代码获取语言
  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.zh,
    );
  }
}

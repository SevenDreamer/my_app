import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:my_app/core/models/app_language.dart';
import 'package:my_app/core/theme/app_theme_scope.dart';
import 'package:my_app/core/theme/app_theme_mode.dart';
import 'package:my_app/core/widgets/app_card.dart';
import 'package:my_app/core/widgets/settings_row.dart';

/// 通用设置面板
class GeneralSettingsPanel extends StatefulWidget {
  const GeneralSettingsPanel({super.key});

  @override
  State<GeneralSettingsPanel> createState() => _GeneralSettingsPanelState();
}

class _GeneralSettingsPanelState extends State<GeneralSettingsPanel> {
  AppLanguage _language = AppLanguage.zh;

  void _changeLanguage(AppLanguage lang) {
    setState(() => _language = lang);
  }

  @override
  Widget build(BuildContext context) {
    final themeScope = AppThemeScope.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '通用设置',
            style: Theme.of(context).typography.h3,
          ),
          const SizedBox(height: 24),
          AppCard.low(
            child: Column(
              children: [
                SettingsRow(
                  icon: LucideIcons.sunMoon,
                  title: '主题模式',
                  subtitle: themeScope.mode.displayName,
                  onTap: () => _showThemeDialog(themeScope),
                ),
                const Divider(),
                SettingsRow(
                  icon: LucideIcons.globe,
                  title: '语言',
                  subtitle: _language.displayName,
                  onTap: _showLanguageDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(AppThemeScopeState themeScope) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择主题'),
        content: RadioGroup<AppThemeMode>(
          value: themeScope.mode,
          onChanged: (v) {
            themeScope.setMode(v);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemeMode.values
                .map((mode) => RadioItem(
                      value: mode,
                      trailing: Text(mode.displayName),
                    ),)
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择语言'),
        content: RadioGroup<AppLanguage>(
          value: _language,
          onChanged: (v) {
            _changeLanguage(v);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values
                .map((lang) => RadioItem(
                      value: lang,
                      trailing: Text(lang.displayName),
                    ),)
                .toList(),
          ),
        ),
      ),
    );
  }
}

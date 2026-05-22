import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sub_app_shared/sub_app_shared.dart';

/// 应用管理面板 - 支持子应用开关和版本管理
class AppManagementPanel extends StatefulWidget {
  const AppManagementPanel({super.key});

  @override
  State<AppManagementPanel> createState() => _AppManagementPanelState();
}

class _AppManagementPanelState extends State<AppManagementPanel> {
  Map<String, bool> _appEnabled = {};

  @override
  void initState() {
    super.initState();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, bool> enabled = {};
    for (final app in SubAppRegistry.all) {
      enabled[app.id] = prefs.getBool('app_enabled_${app.id}') ?? true;
    }
    setState(() {
      _appEnabled = enabled;
    });
  }

  Future<void> _toggleApp(String id, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_enabled_$id', value);
    // 同步更新 SubAppRegistry，立即生效
    if (value) {
      SubAppRegistry.enable(id);
    } else {
      SubAppRegistry.disable(id);
    }
    setState(() {
      _appEnabled[id] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = SubAppRegistry.all;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '应用管理',
                style: ShadTheme.of(context).textTheme?.titleLarge,
              ),
              ShadButton.outline(
                onPressed: () {
                  // TODO: 添加新应用
                },
                child: const Icon(LucideIcons.plus, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: apps.length * 2 - 1,
              itemBuilder: (context, index) {
                if (index.isOdd) {
                  return const SizedBox(height: 12);
                }
                final appIndex = index ~/ 2;
                final app = apps[appIndex];
                final enabled = _appEnabled[app.id] ?? true;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          app.icon,
                          size: 32,
                          color: enabled
                              ? ShadTheme.of(context).colorScheme?.primary
                              : ShadTheme.of(context)
                                  .colorScheme
                                  ?.mutedForeground,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: ShadTheme.of(context)
                                    .textTheme
                                    ?.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                app.description,
                                style: ShadTheme.of(context)
                                    .textTheme
                                    ?.bodySmall
                                    ?.copyWith(
                                      color: ShadTheme.of(context)
                                          .colorScheme
                                          ?.mutedForeground,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '版本: ${app.version ?? "1.0.0"}',
                                style: ShadTheme.of(context)
                                    .textTheme
                                    ?.bodySmall
                                    ?.copyWith(
                                      fontSize: 12,
                                      color: ShadTheme.of(context)
                                          .colorScheme
                                          ?.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: enabled,
                          onChanged: (value) => _toggleApp(app.id, value),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

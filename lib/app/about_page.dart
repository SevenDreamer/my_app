//! 「关于」页：版本信息与更新检查
//!
//! 精简两行：当前版本（展示）、版本更新（检查并提示）。
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design/tokens.dart';
import '../design/widgets/app_header.dart';
import '../design/widgets/app_scaffold.dart';
import '../design/widgets/app_setting_row.dart';
import '../design/widgets/app_toast.dart';
import 'update/update_notice_dialog.dart';
import 'update/update_service.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();
  bool _checking = false;

  /// 检查大版本更新：有新版弹提示框，没有则 toast
  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService().check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info != null) {
      await showUpdateNotice(context, info);
    } else {
      AppToast.show(context, '已是最新版本');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '关于'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppSettingRow(
                  icon: LucideIcons.info,
                  title: '当前版本',
                  trailing: FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                          : '…',
                      style: AppTypography.labelSm,
                    ),
                  ),
                ),
                AppSettingRow(
                  icon: LucideIcons.refreshCw,
                  title: '版本更新',
                  detail: _checking ? '检查中…' : null,
                  onTap: _checkUpdate,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//! 「关于」页：版本信息与更新中心
//!
//! 三行：当前版本（展示）、热更状态（Shorebird patch 可见化）、
//! 检查更新（大版本有新版弹提示框，没有则 toast）。
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

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
  String _patchInfo = '检测中…';

  @override
  void initState() {
    super.initState();
    // ignore: unawaited_futures
    _refreshPatchInfo();
  }

  /// 热更状态（当前 Patch 号 + 是否有已下载待重启的更新）
  Future<void> _refreshPatchInfo() async {
    try {
      final updater = ShorebirdUpdater();
      final current = await updater.readCurrentPatch();
      final next = await updater.readNextPatch();
      final text = 'Patch ${current?.number ?? '基线（无补丁）'}'
          '${next != null ? ' · Patch ${next.number} 已下载，重启生效' : ''}';
      if (mounted) setState(() => _patchInfo = text);
    } catch (e) {
      if (mounted) setState(() => _patchInfo = '非热更包/检测失败：$e');
    }
  }

  /// 检查更新：有新版弹提示框，没有则 toast
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
                  icon: LucideIcons.zap,
                  title: '热更状态',
                  detail: _patchInfo,
                  onTap: _refreshPatchInfo,
                ),
                AppSettingRow(
                  icon: LucideIcons.refreshCw,
                  title: '检查更新',
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

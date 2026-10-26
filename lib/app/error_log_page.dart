//! 错误日志页：历史错误列表（最新在前，点条目回看完整详情）
import 'package:flutter/widgets.dart';
import '../design/widgets/app_spinner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design/tokens.dart';
import '../design/widgets/app_scaffold.dart';

import '../core/errors/error_codes.dart';
import '../core/errors/error_dialog.dart';
import '../core/errors/error_log.dart';
import '../design/widgets/app_header.dart';
import '../design/widgets/app_list_tile.dart';

class ErrorLogPage extends StatefulWidget {
  const ErrorLogPage({super.key});

  @override
  State<ErrorLogPage> createState() => _ErrorLogPageState();
}

class _ErrorLogPageState extends State<ErrorLogPage> {
  List<ErrorLogEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ErrorLog.recent();
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  String _fmt(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '错误日志'),
      body: _loading
          ? const Center(child: AppSpinner())
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    '还没有错误记录\n一切正常 🎉',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  children: [
                    for (final e in _entries)
                      AppListTile(
                        icon: LucideIcons.bug,
                        title:
                            '${e.error.code} · ${ErrorCodes.categoryOf(e.error.code)}'
                            '${e.error.context != null ? '（${e.error.context}）' : ''}',
                        subtitle: e.error.message,
                        trailing: Text(
                          _fmt(e.time),
                          style: AppTypography.labelSm,
                        ),
                        onTap: () => showErrorDialog(
                          context,
                          e.error,
                          record: false, // 回看历史，不再重复记录
                        ),
                      ),
                  ],
                ),
    );
  }
}

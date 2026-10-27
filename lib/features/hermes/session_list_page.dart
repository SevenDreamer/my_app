//! Hermes 会话列表页：搜索 + 列表 + 新建（G2）
//!
//! MVVM：只读 HermesViewModel 快照 + 调命令方法。
//! 时间分组待字段级契约确认后细化（协议清单 §7），先按时间倒序平铺。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'chat_page.dart';
import 'hermes_view_model.dart';

class SessionListPage extends StatefulWidget {
  const SessionListPage({super.key, required this.vm});

  final HermesViewModel vm;

  @override
  State<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends State<SessionListPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.vm.refreshSessions();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(SessionInfo session) {
    widget.vm.openSession(session.id);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => ChatPage(vm: widget.vm),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _create() {
    widget.vm.newSession();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => ChatPage(vm: widget.vm),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '会话'),
      body: ListenableBuilder(
        listenable: widget.vm,
        builder: (context, _) {
          final q = _search.text.trim().toLowerCase();
          final sessions = widget.vm.sessions
              .where((s) =>
                  q.isEmpty || s.title.toLowerCase().contains(q))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        controller: _search,
                        placeholder: const Text('搜索会话…'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ShadButton(onPressed: _create, child: const Text('新会话')),
                  ],
                ),
              ),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(
                        child: Text(
                          '（暂无会话——点「新会话」开始）',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        itemCount: sessions.length,
                        itemBuilder: (context, i) {
                          final s = sessions[i];
                          final running = s.id == widget.vm.sessionId &&
                              widget.vm.busy;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm),
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: AppColors.border)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.title.isEmpty
                                              ? '未命名会话'
                                              : s.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          '${s.id}'
                                          '${s.updatedAt == null || s.updatedAt!.isEmpty ? '' : ' · ${s.updatedAt}'}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (running)
                                    const Text(
                                      '运行中…',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

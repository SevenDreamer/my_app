//! Hermes 会话页：消息流 + 工具卡 + 审批卡 + 输入条
//!
//! MVVM：只读 HermesViewModel 快照 + 调命令方法。
//! 流式事件（message.*/tool.*/approval.*）语义见 docs/HERMES_GATEWAY_PROTOCOL.md §4。
import 'package:flutter/widgets.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'hermes_view_model.dart';

/// markdown 渲染配置（吃 tokens：正文字号/代码块底色/圆角）
final _mdConfig = MarkdownConfig(
  configs: [
    const PConfig(
      textStyle: TextStyle(
          fontSize: 14, color: AppColors.onSurface, height: 1.55),
    ),
    PreConfig(
      textStyle:
          const TextStyle(fontSize: 12, color: AppColors.onSurface, height: 1.5),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    CodeConfig(
      style: TextStyle(
        fontSize: 12,
        color: AppColors.onSurface,
        backgroundColor: AppColors.border.withValues(alpha: 0.4),
      ),
    ),
  ],
);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.vm});

  final HermesViewModel vm;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: '会话'),
      body: ListenableBuilder(
        listenable: widget.vm,
        builder: (context, _) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
          final entries = widget.vm.entries;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: entries.length + (widget.vm.thinking ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == entries.length) {
                      return const _HintLine('思考中…');
                    }
                    return _EntryCard(
                      entry: entries[i],
                      onTap: entries[i].kind == 'tool'
                          ? () => widget.vm.toggleEntry(entries[i])
                          : null,
                      onRespond: entries[i].kind == 'approval' && !entries[i].done
                          ? (ok) => widget.vm.respondApproval(entries[i], ok)
                          : null,
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _input,
                busy: widget.vm.busy,
                onSend: () {
                  final text = _input.text;
                  _input.clear();
                  widget.vm.send(text);
                },
                onStop: () => widget.vm.stop(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 单条记录（对话/工具/系统/审批）
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.onTap, this.onRespond});

  final ChatEntry entry;
  final VoidCallback? onTap;
  final void Function(bool approved)? onRespond;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.kind == 'user';
    final isTool = entry.kind == 'tool';
    final isSystem = entry.kind == 'system';
    final isApproval = entry.kind == 'approval';
    final label = switch (entry.kind) {
      'user' => '你',
      'tool' => '工具',
      'system' => '系统',
      'approval' => '审批',
      _ => 'Hermes',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.secondary),
          ),
          const SizedBox(height: 2),
          if (isApproval)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.text.isEmpty ? '批准一项操作？' : entry.text,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (!entry.done && onRespond != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        ShadButton(
                          size: ShadButtonSize.sm,
                          onPressed: () => onRespond!(true),
                          child: const Text('允许'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ShadButton.destructive(
                          size: ShadButtonSize.sm,
                          onPressed: () => onRespond!(false),
                          child: const Text('拒绝'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : isTool || isSystem
                          ? AppColors.border.withValues(alpha: 0.4)
                          : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: isTool || isSystem
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: isUser || isTool || isSystem
                    ? Text(
                        entry.text.isEmpty ? '…' : entry.text,
                        style: TextStyle(
                          fontSize: isTool || isSystem ? 12 : 14,
                          color: isTool || isSystem
                              ? AppColors.secondary
                              : AppColors.onSurface,
                        ),
                      )
                    : MarkdownBlock(
                        data: entry.text.isEmpty ? '…' : entry.text,
                        config: _mdConfig,
                      ),
              ),
            ),
          if (isTool && entry.expanded && entry.meta != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                entry.meta!.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.secondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.secondary),
      ),
    );
  }
}

/// 输入条：输入框 + 发送/停止
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ShadInput(
              controller: controller,
              placeholder: const Text('输入消息…'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          busy
              ? ShadButton.destructive(
                  onPressed: onStop,
                  child: const Text('停止'),
                )
              : ShadButton(onPressed: onSend, child: const Text('发送')),
        ],
      ),
    );
  }
}

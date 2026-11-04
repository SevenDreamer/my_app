//! DSH 对话页（shadcn 风格聊天面：连接栏 + 消息流 + 输入条）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_scaffold.dart';
import 'dsh_chat_view_model.dart';

class DshChatPage extends StatefulWidget {
  const DshChatPage({super.key, this.viewModel});

  final DshChatViewModel? viewModel;

  @override
  State<DshChatPage> createState() => _DshChatPageState();
}

class _DshChatPageState extends State<DshChatPage> {
  late final DshChatViewModel _viewModel =
      widget.viewModel ?? DshChatViewModel();
  final _input = TextEditingController();

  @override
  void dispose() {
    if (widget.viewModel == null) _viewModel.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    _input.clear();
    _viewModel.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: Text(_viewModel.status,
                      style: AppTypography.bodyMd.copyWith(
                        color: ShadTheme.of(context).colorScheme.mutedForeground,
                      )),
                ),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _viewModel.messages.length,
                itemBuilder: (context, i) {
                  final m = _viewModel.messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isUser
                            ? ShadTheme.of(context).colorScheme.primary
                            : ShadTheme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text,
                          style: AppTypography.bodyMd.copyWith(
                            color: isUser
                                ? ShadTheme.of(context).colorScheme.primaryForeground
                                : ShadTheme.of(context).colorScheme.foreground,
                          )),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: ShadInput(
                    controller: _input,
                    placeholder: const Text('对 DSH 说点什么…（/ 唤起命令）'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _viewModel.sending ? null : _send,
                  child: const Text('发送'),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: () => _viewModel.startEngine(),
                  child: const Text('启动引擎'),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

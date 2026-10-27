//! Hermes 入口页：连接 gateway（Remote 模式）→ 进入会话
//!
//! MVVM：只读 HermesViewModel 快照 + 调命令方法。
//! 连接形态见 docs/HERMES_GATEWAY_PROTOCOL.md §2（远程 token/OAuth）。
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_header.dart';
import '../../design/widgets/app_scaffold.dart';
import 'hermes_view_model.dart';
import 'session_list_page.dart';

class HermesHomePage extends StatefulWidget {
  const HermesHomePage({super.key});

  @override
  State<HermesHomePage> createState() => _HermesHomePageState();
}

class _HermesHomePageState extends State<HermesHomePage> {
  late final HermesViewModel _vm;
  final _url = TextEditingController(text: 'ws://127.0.0.1:9120/api/ws');
  final _token = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = HermesViewModel();
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppHeader(title: 'Hermes'),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final connected = _vm.status == GatewayStatus.connected;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '两种接入方式：\n'
                  '① 本机 Termux——Termux 里执行 '
                  '「hermes config set webapp.enabled true」并启动 gateway，'
                  '然后点下方「检测本机网关」（token 留空）；\n'
                  '② 远程 gateway——填 PC/Mac 的 ws://主机:端口/api/ws。',
                  style: TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
                const SizedBox(height: AppSpacing.md),
                ShadInput(
                  controller: _url,
                  placeholder: const Text('ws://127.0.0.1:9120/api/ws'),
                ),
                const SizedBox(height: AppSpacing.sm),
                ShadInput(
                  controller: _token,
                  placeholder: const Text('token（本机可空）'),
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (!connected) ...[
                      ShadButton(
                        onPressed: () => _vm.detectAndConnect(_token.text),
                        child: const Text('检测本机网关'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    ShadButton(
                      onPressed: connected
                          ? () => _vm.disconnect()
                          : () => _vm.connect(_url.text, _token.text),
                      child: Text(connected ? '断开' : '连接'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ShadButton.outline(
                      onPressed: connected
                          ? () => Navigator.of(context).push(
                                PageRouteBuilder<void>(
                                  pageBuilder: (_, __, ___) =>
                                      SessionListPage(vm: _vm),
                                  transitionsBuilder:
                                      (_, animation, __, child) =>
                                          FadeTransition(
                                              opacity: animation, child: child),
                                ),
                              )
                          : null,
                      child: const Text('会话列表'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '状态：${_vm.statusText}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

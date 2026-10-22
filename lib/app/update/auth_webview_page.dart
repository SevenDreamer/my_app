//! 内置 webview 授权页（Android 专用）：授权页开在 app 内部
//!
//! 受控容器的价值：不受外部浏览器/应用选择器/厂商策略打断；
//! token 仍由后台轮询获取（webview 不接触 token），只是环境更稳。
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/widgets/app_header.dart';

class AuthWebviewPage extends StatefulWidget {
  const AuthWebviewPage({
    super.key,
    required this.url,
    required this.userCode,
  });

  /// 授权链接（已带 user_code 自动填码）
  final String url;

  /// 配对码（标题展示，方便手动兜底）
  final String userCode;

  @override
  State<AuthWebviewPage> createState() => _AuthWebviewPageState();
}

class _AuthWebviewPageState extends State<AuthWebviewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: '授权 GitHub · ${widget.userCode}'),
      body: WebViewWidget(controller: _controller),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Text(
            '在上方页面完成授权后返回上一页——本窗口会自动继续，配对码万一没自动填就手动输入。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

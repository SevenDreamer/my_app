//! dsh-go 应用壳宿主（批次 4 点亮）：把上游 `main()` 的装配链收进可嵌入 Widget。
//!
//! 第一阶段照搬不改（决策 7）：ProviderScope + 语言/启动状态初始化 + 第三方
//! 许可注册后进入上游 [DshApp] 整壳（自带对话/市场/遥控/设置全导航）。
//! 与 my_app 的 SentryBridge 并存（appErrorCapture 是上游本地诊断日志，
//! 不外发，装上供其错误页使用）。SystemChrome 全局样式照装（上游页面的
//! AnnotatedRegion 依赖 edgeToEdge 模式）。
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'diagnostics/app_error_log.dart';
import 'launch/launch_state.dart';
import 'state/locale_state.dart';
import 'ui/common/third_party_licenses.dart';
import 'ui/settings/font_licenses.dart';
import 'ui/theme/theme.dart';

class DshGoHost extends StatefulWidget {
  const DshGoHost({super.key});

  @override
  State<DshGoHost> createState() => _DshGoHostState();
}

class _DshGoHostState extends State<DshGoHost> {
  late final Future<void> _ready = _init();

  Future<void> _init() async {
    appErrorCapture.install();
    await Future.wait([AppLanguageController.load(), LaunchController.begin()]);
    registerThirdPartyLicenses();
    registerFontLicenses();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
        dshSystemOverlay(PlatformDispatcher.instance.platformBrightness));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // ProviderScope 已提升至 my_app 根（main.dart），此处直接进上游壳
        //——内层再包一层会与 rootOverlay 插层（ChatAlertHost 等）状态分裂。
        return const DshApp();
      },
    );
  }
}

//! 前台窗口跟踪（原版 ForegroundActivity 的 Flutter 重写）。
//!
//! 契约保留：isResumed 语义 =「活跃前台且非销毁中」（原版要求主线程复核、
//! 至少 RESUMED、非 finishing/destroyed）；resume/pause 成对通知
//! （原版 onActivityResumed → foreground().resume + 保活，left() → pause）。
import 'package:flutter/widgets.dart';

class ForegroundTracker with WidgetsBindingObserver {
  ForegroundTracker({required this.onResume, required this.onPause});

  final void Function() onResume;
  final void Function() onPause;

  bool _resumed = false;

  /// 原版 isResumed()：活跃前台且非销毁中。
  bool isResumed() => _resumed;

  /// 挂载（页面/VM 初始化时调用）。
  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _sync(WidgetsBinding.instance.lifecycleState);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    _resumed = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState? state) {
    _sync(state);
  }

  void _sync(AppLifecycleState? state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _resumed) return;
    _resumed = resumed;
    if (resumed) {
      onResume();
    } else {
      onPause();
    }
  }
}

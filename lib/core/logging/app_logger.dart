//! 应用日志收集器（调试用）：内存 ring buffer + 实时刷新
//!
//! 调试期看"发生了什么"用：各模块把关键事件/错误打进这里，
//! 界面右上角日志图标一键查看。只进内存（不落盘）——错误日志的
//! 落盘在 core/errors（error.log），两者分工。
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _capacity = 200;
  final ValueListenable<List<String>> entries = _entries;
  static final _entries = ValueNotifier<List<String>>(const []);

  void log(String tag, String message) {
    final time = DateTime.now();
    final line =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} [$tag] $message';
    debugPrint('APPLOG $line');
    final list = [..._entries.value, line];
    _entries.value =
        list.length > _capacity ? list.sublist(list.length - _capacity) : list;
  }
}

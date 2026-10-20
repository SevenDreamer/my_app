//! 错误日志：本地 jsonl 落盘（最近 50 条），供「我」页错误日志回看
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_error.dart';

class ErrorLogEntry {
  const ErrorLogEntry({
    required this.time,
    required this.error,
  });

  final DateTime time;
  final AppError error;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'code': error.code,
        'message': error.message,
        'context': error.context,
        'hint': error.hint,
        'detail': error.detail,
      };

  static ErrorLogEntry? fromJson(Map<String, dynamic> j) {
    final code = j['code'] as String?;
    if (code == null) return null;
    return ErrorLogEntry(
      time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      error: AppError(
        code: code,
        message: j['message'] as String? ?? '',
        context: j['context'] as String?,
        hint: j['hint'] as String?,
        detail: j['detail'] as String?,
      ),
    );
  }
}

abstract class ErrorLog {
  static const int _maxEntries = 50;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/my_app_error_log.jsonl');
  }

  /// 记录一条错误（写入失败静默——日志本身不该再制造错误）
  static Future<void> record(AppError error) async {
    try {
      final f = await _file();
      final entry = ErrorLogEntry(time: DateTime.now(), error: error);
      await f.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
      );
      // 环形截断：超过上限保留最新 _maxEntries 条
      final lines = await f.readAsLines();
      if (lines.length > _maxEntries) {
        await f.writeAsString(
          '${lines.sublist(lines.length - _maxEntries).join('\n')}\n',
        );
      }
    } catch (_) {
      // 日志写入失败不影响主流程
    }
  }

  /// 读取历史（最新在前）
  static Future<List<ErrorLogEntry>> recent() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      final lines = await f.readAsLines();
      final entries = <ErrorLogEntry>[];
      for (final line in lines.reversed) {
        if (line.trim().isEmpty) continue;
        final e = ErrorLogEntry.fromJson(
          jsonDecode(line) as Map<String, dynamic>,
        );
        if (e != null) entries.add(e);
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }
}

// BackgroundRustArchiveExtractor 冒烟：后台隔离岛解包端到端。
// 用法：dart run tool/smoke_background_extract.dart [解包库目录]
import 'dart:io';

import 'package:dsha_core/dsha_core.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    // DLL 搜索走 PATH（DynamicLibrary.open 语义）。
    Platform.environment['PATH']; // 只读；调用方应预先 export PATH
  }
  final extractor = await BackgroundRustArchiveExtractor.open();
  if (extractor == null) {
    stderr.writeln('SMOKE_FAIL: 后台解包器开岛失败（库缺位?）');
    exit(1);
  }
  final tmp = Directory.systemTemp.createTempSync('bg-extract-smoke');
  final archive =
      File('D:/Projects/my_app/assets/dsha/python-support.bin').absolute.path;
  var last = -1;
  final sw = Stopwatch()..start();
  await extractor.extract(archive, tmp.path, onProgress: (done, total) {
    if (done != last && (done == total || done % (total ~/ 4 + 1) == 0)) {
      print('progress: $done / $total');
      last = done;
    }
  });
  sw.stop();
  final files = tmp
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceFirst(tmp.path, ''))
      .toList()
    ..sort();
  print('elapsed: ${sw.elapsedMilliseconds}ms, files: ${files.length}');
  print('sample: ${files.take(4).toList()}');
  // 契约：python-support.bin = libsqlite3/libreadline soname 对
  final ok = files.any((p) => p.contains('libsqlite3.so.0')) &&
      files.any((p) => p.contains('libreadline.so.8'));
  extractor.close();
  tmp.deleteSync(recursive: true);
  if (!ok) {
    stderr.writeln('SMOKE_FAIL: soname 契约不符');
    exit(1);
  }
  print('SMOKE_BACKGROUND_EXTRACT_PASS');
}

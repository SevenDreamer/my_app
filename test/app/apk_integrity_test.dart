//! APK 完整性校验单测（测试安全网——拒装分支实证）。
//!
//! 真临时文件 + 真 Rust FFI（dll 在位时）；dll 缺席时核心断言 skip
//! （跳过分支与空值分支不依赖 Rust，始终跑）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/update/apk_installer.dart';
import 'package:my_app/core/ffi/rust_core.dart';

void main() {
  final dll = File('build/windows/x64/runner/Debug/core.dll');
  final hasDll = dll.existsSync();
  if (hasDll) {
    // 预热单例（Windows DLL 加载不搜 cwd——PITFALLS #42）
    RustCore.ensureLoaded(libraryPath: dll.absolute.path);
  }

  test('空/缺期望值跳过校验（旧 manifest 兼容）', () {
    final f = File('${Directory.systemTemp.path}/apk_test_skip.bin')
      ..writeAsStringSync('anything');
    expect(verifyApkIntegrity(f, null), isNull);
    expect(verifyApkIntegrity(f, ''), isNull);
    expect(f.existsSync(), isTrue, reason: '跳过时不得删文件');
    f.deleteSync();
  });

  test('SHA-256 匹配放行 / 不匹配拒装删文件（E3004）', () {
    if (!hasDll) {
      markTestSkipped('core.dll 未构建（tool/rust-dev.sh 后重跑）');
      return;
    }
    // 'abc' 内容 → NIST 向量
    final ok = File('${Directory.systemTemp.path}/apk_test_ok.bin')
      ..writeAsStringSync('abc');
    expect(
      verifyApkIntegrity(
          ok, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
      isNull,
      reason: '匹配须放行',
    );
    expect(ok.existsSync(), isTrue);
    ok.deleteSync();

    // 不匹配 → 拒装 + 删文件
    final bad = File('${Directory.systemTemp.path}/apk_test_bad.bin')
      ..writeAsStringSync('tampered');
    final err = verifyApkIntegrity(bad, 'deadbeef');
    expect(err, isNotNull);
    expect(err!.code, 'E3004');
    expect(bad.existsSync(), isFalse, reason: '拒装须删除文件');
  });

  test('大小写不敏感匹配（manifest 大写 sha 也过）', () {
    if (!hasDll) {
      markTestSkipped('core.dll 未构建');
      return;
    }
    final f = File('${Directory.systemTemp.path}/apk_test_case.bin')
      ..writeAsStringSync('abc');
    expect(
      verifyApkIntegrity(
          f, 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'),
      isNull,
    );
    f.deleteSync();
  });
}

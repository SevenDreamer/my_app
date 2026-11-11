//! Rust core FFI 集成测试——DLL 在位才测（CI/无构建环境自动跳过）。
//!
//! 验证 FFI 双向通路：心跳/算术/SHA-256（NIST 向量经 FFI 过界）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/ffi/rust_core.dart';

void main() {
  final dllPath = Platform.isWindows
      ? 'build/windows/x64/runner/Debug/core.dll'
      : 'build/linux/x64/debug/bundle/lib/libcore.so';
  final hasDll = File(dllPath).existsSync();

  test('Rust core 心跳 + SHA-256 NIST 向量（FFI 过界）', () async {
    if (!hasDll) {
      markTestSkipped('core.dll 未构建（cargo build --release 后重跑）');
      return;
    }
    final rc = RustCore.ensureLoaded(
        libraryPath: File(dllPath).absolute.path,
      );
    expect(rc, isNotNull, reason: 'core.dll 在位但加载失败');
    expect(rc!.version(), startsWith('core-rs-'));
    expect(rc.add(2, 3), 5);
    // 空串 SHA-256（NIST）
    expect(
      rc.sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    // 'abc' SHA-256（NIST）
    expect(
      rc.sha256Hex('abc'.codeUnits),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    // 文件流式版与内存版一致性（临时文件）
    final tmp = File('${Directory.systemTemp.path}/rust_core_test.txt')
      ..writeAsStringSync('abc');
    expect(
      rc.sha256File(tmp.path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(rc.sha256File('/nonexistent/core_test'), isNull);
    tmp.deleteSync();
    expect(rc.buildInfo(), contains('target='));
  });
}

// 契约回归（MY-APP-5/6）：虚拟屏启动通道的输出必须带 `[EXIT=0]` 尾标，
// `VscreenHandshake.started` 才认领握手——原版 ShellService.executeArgv 的
// 输出契约（`output + "\n[EXIT=" + exitCode + "]"`）。
//
// 真因链：ShellService.kt 的 execVirtualScreen runner 曾只返回进程首行、
// 无尾标 → started() 恒 null → 每次启动必判 VSCREEN_START_UNKNOWN →
// 进入 startUnknown + cleanupPending 屏障，同一开机内后续点击全部短路。
import 'package:dsha_core/dsha_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
  const identity = '1000:1700000000:1000:'
      '11111111-2222-3333-4444-555555555555:'
      'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
  const started = 'DSHA_VSCREEN_STARTED 1 45678 $token $identity';

  test('修复后的通道输出（STARTED 行 + [EXIT=0] 尾标）解析出握手', () {
    final handshake = VscreenHandshake.started('$started\n[EXIT=0]\n');
    expect(handshake, isNotNull);
    expect(handshake!.port, 45678);
    expect(handshake.token, token);
    expect(handshake.identity.uid, 1000);
  });

  test('缺 [EXIT=0] 尾标的首行输出必须判结果未知（旧 runner 行为）', () {
    expect(VscreenHandshake.started(started), isNull);
  });

  test('进程失败输出（[EXIT=1] + 错误码）不得认领握手', () {
    const failed = 'DSHA_VSCREEN_ERROR=CORE_START_SDK36_FAILED\n[EXIT=1]';
    expect(VscreenHandshake.started(failed), isNull);
  });
}

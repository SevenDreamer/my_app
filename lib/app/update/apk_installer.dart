//! app 内下载并安装 APK（D1）：跳过浏览器，游戏式更新体验
//!
//! 流程：签名 URL → http 流式下载到临时目录（进度回调）→ open_file 调起
//! 系统安装器（首次系统弹"允许安装未知应用"授权，一次即可）。
//! 只适用于 Android；失败统一走 AppError（错误码系统）。
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/ffi/rust_core.dart';
import '../../core/logging/sentry_bridge.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_codes.dart';

/// 本机首选 ABI（arm64-v8a / armeabi-v7a / x86_64…，D2 分架构选包用）
Future<String> deviceAbi() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.supportedAbis.isNotEmpty
        ? info.supportedAbis.first
        : 'arm64-v8a';
  } catch (_) {
    return 'arm64-v8a'; // 查询失败按主流架构兜底
  }
}

/// 下载 APK 并调起安装；[onProgress] 回报 0..1。
/// [expectSha256]（R2 manifest 提供）下载完成后经 Rust core 流式校验——
/// 不匹配即拒装并删文件（供应链完整性防护，2026-11-10 补）。
/// 返回 null 表示成功；失败返回 AppError（交给错误弹窗）。
Future<AppError?> downloadAndInstallApk(
  String url, {
  void Function(double progress)? onProgress,
  String? expectSha256,
}) async {
  try {
    final client = http.Client();
    final target = http.Request('GET', Uri.parse(url));
    final streamed = await client.send(target);
    if (streamed.statusCode != 200) {
      client.close();
      return AppError(
        code: ErrorCodes.updateSignedUrl,
        message: '下载失败（HTTP ${streamed.statusCode}）',
      );
    }

    // 流式写入临时文件（边下边报进度）
    final total = streamed.contentLength ?? 0;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/my_app-update.apk');
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.flush();
    await sink.close();
    client.close();

    // 完整性校验（Rust core 流式 SHA-256，零双拷贝）——
    // manifest 提供期望值才校验（向后兼容旧 manifest）
    if (expectSha256 != null && expectSha256.isNotEmpty) {
      final actual = RustCore.ensureLoaded()?.sha256File(file.path);
      if (actual == null) {
        // Rust 核心不可用：降级放行（增强件原则）但留 breadcrumb
        SentryBridge.breadcrumb(
            'update.verify_skipped', 'rust-core-unavailable');
      } else if (actual.toLowerCase() != expectSha256.toLowerCase()) {
        file.deleteSync();
        return AppError(
          code: ErrorCodes.updateChecksum,
          message: '安装包完整性校验失败（SHA-256 不匹配），已拒绝安装',
          detail: 'expected=$expectSha256 actual=$actual',
        );
      }
    }

    // 调起系统安装器（首次系统弹"允许安装未知应用"授权）
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      return AppError(
        code: ErrorCodes.unknown,
        message: '调起安装器失败',
        detail: result.message,
      );
    }
    return null;
  } catch (e) {
    return AppError.from(e, context: '下载安装更新');
  }
}

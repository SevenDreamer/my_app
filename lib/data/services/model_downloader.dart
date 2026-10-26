//! Live2D 模型下载服务（数据层）——模型资产按需从 R2 拉取
//!
//! 背景：三个 Live2D 模型的贴图占安装包 33MB+（一半以上），
//! 按需下载可把安装包从 56MB 砍到 ~22MB。模型是"内容"不是"代码"，
//! 运行时下载合法可行（原生代码/Flutter AOT 则不可动态加载）。
//!
//! 流程：下载 zip → SHA256 校验 → 解压到应用私有目录 →
//! live2d 插件的 loadModel 直接吃文件路径（插件原生支持三源：
//! http URL / asset 路径 / 文件系统路径）。

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../live2d_models.dart';

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ModelDownloader {
  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 模型存储根目录：应用私有目录/live2d_models/<id>/
  Future<Directory> _rootDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/live2d_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 模型是否已下载（入口文件存在即视为完整——zip 中断不会留下入口）
  Future<bool> isDownloaded(ModelDef model) async {
    final entry = await localEntryPath(model);
    return File(entry).exists();
  }

  /// 已下载模型的入口文件绝对路径（model3.json）
  Future<String> localEntryPath(ModelDef model) async {
    final root = await _rootDir();
    return '${root.path}/${model.id}/${model.file}';
  }

  /// 下载并解压模型。[onProgress] 回传 0-1。
  /// 完成后返回入口文件绝对路径；失败抛 [ModelDownloadException]。
  Future<String> download(ModelDef model,
      {void Function(double progress)? onProgress}) async {
    final url = model.zipUrl;
    if (url == null) {
      throw const ModelDownloadException('该模型不支持下载');
    }

    final root = await _rootDir();
    final dest = Directory('${root.path}/${model.id}');
    final zipFile = File('${root.path}/${model.id}.zip.tmp');

    try {
      // 1) 下载 zip（一次读全量——模型包最大 18MB，内存可承受；
      //    http 分块流式留待后续优化）
      final resp = await _client.send(http.Request('GET', Uri.parse(url)));
      if (resp.statusCode != 200) {
        throw ModelDownloadException('下载失败（HTTP ${resp.statusCode}）');
      }
      final total = resp.contentLength ?? model.zipSize ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in resp.stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      final bytes = builder.takeBytes();

      // 2) SHA256 校验（清单带校验和时）
      final expect = model.sha256;
      if (expect != null && expect.isNotEmpty) {
        final digest = sha256.convert(bytes).toString();
        if (digest != expect) {
          throw const ModelDownloadException('校验失败，文件已损坏，请重试');
        }
      }
      await zipFile.writeAsBytes(bytes, flush: true);

      // 3) 解压到 live2d_models/<id>/
      if (await dest.exists()) await dest.delete(recursive: true);
      await dest.create(recursive: true);
      await _extractZip(zipFile, dest);

      // 4) 入口文件确认（下载/解压完整性判据）
      final entry = File('${dest.path}/${model.file}');
      if (!await entry.exists()) {
        throw ModelDownloadException('解压后找不到模型入口 ${model.file}');
      }
      return entry.path;
    } catch (e) {
      if (e is ModelDownloadException) rethrow;
      throw ModelDownloadException('下载失败：$e');
    } finally {
      if (await zipFile.exists()) await zipFile.delete();
    }
  }

  /// 删除已下载模型（释放空间）
  Future<void> remove(ModelDef model) async {
    final root = await _rootDir();
    final dest = Directory('${root.path}/${model.id}');
    if (await dest.exists()) await dest.delete(recursive: true);
  }

  Future<void> _extractZip(File zipFile, Directory dest) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      final outPath = '${dest.path}/${entry.name}';
      if (entry.isFile) {
        final f = File(outPath);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.content as List<int>, flush: true);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }
}

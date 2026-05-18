import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:install_plugin/install_plugin.dart';

class UpdateService {
  static const String repoOwner = 'SevenDreamer';
  static const String repoName = 'my_app';
  static const String versionFileUrl =
      'https://raw.githubusercontent.com///dev/version.json';
  static const String releasesUrl = 'https://api.github.com/repos///releases';

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 获取远程版本信息
      final response = await http.get(Uri.parse(versionFileUrl));
      if (response.statusCode == 200) {
        final remoteVersion = json.decode(response.body);
        return {
          'current': currentVersion,
          'remote': remoteVersion['version'],
          'tag': remoteVersion['tag'],
          'buildNumber': remoteVersion['build_number'],
          'hasUpdate': remoteVersion['version'] != currentVersion,
        };
      }
    } catch (e) {
      debugPrint('Check update error: $e');
    }
    return null;
  }

  Future<String?> downloadApk(String tag) async {
    try {
      // 获取 release 信息
      final response = await http.get(Uri.parse(releasesUrl));
      if (response.statusCode == 200) {
        final releases = json.decode(response.body) as List;
        final release = releases.firstWhere(
          (r) => r['tag_name'] == tag,
          orElse: () => null,
        );

        if (release != null) {
          final assets = release['assets'] as List;
          final apkAsset = assets.firstWhere(
            (a) => a['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null) {
            final downloadUrl = apkAsset['browser_download_url'];
            final dir = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/update.apk');

            // 下载 APK
            final apkResponse = await http.get(Uri.parse(downloadUrl));
            await file.writeAsBytes(apkResponse.bodyBytes);

            return file.path;
          }
        }
      }
    } catch (e) {
      debugPrint('Download APK error: $e');
    }
    return null;
  }

  Future<void> installApk(String path) async {
    await InstallPlugin.installApk(path);
  }
}

//! 文件 API（附件/上传下载——端点词汇对齐官方协议）。
import 'connection.dart';

class DshFilesApi {
  DshFilesApi(this._connection);
  final DshConnection _connection;

  /// 工作区文件列表。
  Future<Map<String, Object?>> list({String? path}) async {
    return _connection.exchange('GET', '/api/files/list',
        query: {if (path != null) 'path': path});
  }

  /// 上传（multipart 语义由调用方组装字节）。
  Future<Map<String, Object?>> upload(String sessionId, String name, List<int> bytes) async {
    return _connection.exchange('POST', '/api/files/upload',
        body: {'session': sessionId, 'name': name, 'size': bytes.length});
  }

  /// 下载（返回内容描述；字节流经调用方的载体）。
  Future<Map<String, Object?>> download(String fileId) async {
    return _connection.exchange('GET', '/api/files/download', query: {'file': fileId});
  }
}

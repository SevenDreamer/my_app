import 'package:postgres/postgres.dart';

/// 记账标签
class RecordTag {
  final int id;
  final String name;
  final String type; // 'expense', 'income', 'both'
  final int sortOrder;

  const RecordTag({
    required this.id,
    required this.name,
    required this.type,
    this.sortOrder = 0,
  });

  factory RecordTag.fromRow(List<dynamic> row) {
    return RecordTag(
      id: row[0] as int,
      name: row[1] as String,
      type: row[2] as String,
      sortOrder: row[3] as int,
    );
  }
}

/// 标签服务
class TagService {
  static Connection? _connection;

  static Future<Connection> _getConnection() async {
    _connection ??= await Connection.open(
      Endpoint(
        host: '159.75.98.152',
        port: 5433,
        database: 'bar_manager_system',
        username: 'seven',
        password: 'dQt6yMsCgu',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    return _connection!;
  }

  /// 获取标签列表
  /// [type] 过滤类型: 'expense', 'income', 'both', null=全部
  static Future<List<RecordTag>> getTags({String? type}) async {
    final conn = await _getConnection();

    String query = 'SELECT id, name, type, sort_order FROM record_tag';
    if (type != null) {
      query += " WHERE type = '$type' OR type = 'both'";
    }
    query += ' ORDER BY sort_order';

    final result = await conn.execute(query);
    return result.map((row) => RecordTag.fromRow(row.toList())).toList();
  }

  /// 添加标签
  static Future<RecordTag> addTag(String name, {String type = 'both'}) async {
    final conn = await _getConnection();

    final maxOrder = await conn.execute(
      "SELECT COALESCE(MAX(sort_order), 0) FROM record_tag",
    );
    final sortOrder = (maxOrder.first[0] as int) + 1;

    final result = await conn.execute(
      "INSERT INTO record_tag (name, type, sort_order) VALUES ('$name', '$type', $sortOrder) RETURNING id, name, type, sort_order",
    );

    return RecordTag.fromRow(result.first.toList());
  }

  /// 删除标签
  static Future<void> deleteTag(int id) async {
    final conn = await _getConnection();
    await conn.execute("DELETE FROM record_tag WHERE id = $id");
  }

  /// 断开连接
  static Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}

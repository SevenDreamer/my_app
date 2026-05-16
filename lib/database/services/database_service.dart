import '../models/database_models.dart';

/// 数据库连接服务抽象类
abstract class DatabaseService {
  Future<void> connect();
  Future<void> disconnect();
  Future<List<DatabaseInfo>> getDatabases();
  Future<List<TableInfo>> getTables(String databaseName);
  Future<List<FieldInfo>> getFields(String databaseName, String tableName);
  Future<List<Map<String, dynamic>>> getTableData(String databaseName, String tableName, {int limit = 100, int offset = 0});
  Future<bool> testConnection();
}

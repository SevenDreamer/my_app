import '../models/database_models.dart';
import 'sqlite_service.dart';
import 'postgresql_service.dart';
import 'mysql_service.dart';
import 'mongodb_service.dart';

/// 数据库连接服务抽象类
abstract class DatabaseService {
  Future<void> connect();
  Future<void> disconnect();
  Future<List<DatabaseInfo>> getDatabases();
  Future<List<TableInfo>> getTables(String databaseName);
  Future<List<FieldInfo>> getFields(String databaseName, String tableName);
  Future<List<Map<String, dynamic>>> getTableData(
    String databaseName,
    String tableName, {
    int limit = 100,
    int offset = 0,
  });
  Future<bool> testConnection();
}

/// 数据库服务工厂
/// TODO: 待实现 flutter_rust_bridge Rust API 后完善
class DatabaseServiceFactory {
  static DatabaseService create(DbConnectionConfig config) {
    return switch (config.type) {
      DbType.sqlite => SQLiteService(config),
      DbType.mysql => MySQLService(config),
      DbType.postgresql => PostgreSQLService(config),
      DbType.mongodb => MongoDBService(config),
    };
  }
}

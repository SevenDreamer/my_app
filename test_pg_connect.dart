import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  print('Testing PostgreSQL connection...');
  
  try {
    final connection = await Connection.open(
      Endpoint(
        host: '159.75.98.152',
        port: 5433,
        database: 'bar_manager_system',
        username: 'seven',
        password: 'dQt6yMsCgu',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    
    print('Connected! Testing query...');
    final result = await connection.execute('SELECT version()');
    print('PostgreSQL version: ${result.first[0]}');
    
    await connection.close();
    print('Connection closed. Test passed!');
    exit(0);
  } catch (e) {
    print('Connection failed: $e');
    exit(1);
  }
}

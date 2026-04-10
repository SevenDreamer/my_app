import 'package:flutter/material.dart';
import 'update_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UpdateService _updateService = UpdateService();
  Map<String, dynamic>? _updateInfo;
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await _updateService.checkForUpdate();
    setState(() {
      _updateInfo = info;
      _checking = false;
    });
  }

  Future<void> _downloadAndInstall() async {
    if (_updateInfo?['tag'] == null) return;
    
    setState(() => _downloading = true);
    
    final path = await _updateService.downloadApk(_updateInfo!['tag']);
    
    if (path != null && mounted) {
      await _updateService.installApk(path);
    }
    
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checking ? null : _checkUpdate,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '你好世界 🎉',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 40),
            if (_checking)
              const CircularProgressIndicator()
            else if (_updateInfo != null) ...[
              Text('当前版本: ${_updateInfo!['current'] ?? 'unknown'}'),
              Text('最新版本: ${_updateInfo!['remote'] ?? 'unknown'}'),
              if (_updateInfo!['hasUpdate'] == true) ...[
                const SizedBox(height: 20),
                const Text('发现新版本!', style: TextStyle(color: Colors.green)),
                const SizedBox(height: 10),
                _downloading
                    ? Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text('下载中... ${(_downloadProgress * 100).toStringAsFixed(0)}%'),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: _downloadAndInstall,
                        child: const Text('更新'),
                      ),
              ] else
                const Text('已是最新版本', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}

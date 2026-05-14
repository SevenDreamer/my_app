import 'package:flutter/material.dart';
import 'src/ffi_manual.dart';

void main() {
  // 初始化 FFI（必须在 runApp 前调用）
  HermesFFI.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes Agent',
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
  String _coreVersion = '未连接';
  String _pingResult = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initHermes();
  }

  Future<void> _initHermes() async {
    try {
      final version = HermesFFI.instance.getCoreVersion();
      final initResult = HermesFFI.instance.initHermes(logLevel: 'info');
      setState(() {
        _coreVersion = version;
        _initialized = true;
        _pingResult = initResult;
      });
    } catch (e) {
      setState(() {
        _pingResult = '初始化失败: $e';
      });
    }
  }

  Future<void> _ping() async {
    try {
      final result = HermesFFI.instance.ping();
      setState(() {
        _pingResult = result;
      });
    } catch (e) {
      setState(() {
        _pingResult = 'Ping 失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialized ? _ping : null,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '你好，Hermes Agent 🎉',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 40),
            Text('Core 版本: $_coreVersion'),
            const SizedBox(height: 20),
            if (_pingResult.isNotEmpty) Text('结果: $_pingResult'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initialized ? _ping : null,
              child: const Text('测试 Ping'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final sum = HermesFFI.instance.add(10, 20);
                setState(() {
                  _pingResult = '10 + 20 = $sum';
                });
              },
              child: const Text('测试加法 (10 + 20)'),
            ),
            const SizedBox(height: 20),
            if (!_initialized)
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

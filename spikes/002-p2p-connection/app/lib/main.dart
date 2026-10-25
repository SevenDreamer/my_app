//! 002 spike：flutter_p2p_connection 真机验证
//! 验证点：发现（BLE）/ 连接（凭据）/ 文本互通 / 文件传输 / 断线状态
//! 用法：两台手机装同一个 app，一台进 Host 建组，一台进 Client 连接。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'p2p spike', home: const ModePage());
  }
}

/// 模式选择页：Host 或 Client
class ModePage extends StatelessWidget {
  const ModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('002 p2p spike')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HostPage()),
              ),
              child: const Text('HOST（建组）'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientPage()),
              ),
              child: const Text('CLIENT（连接）'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 公共：权限与服务检查（每步打日志定位卡点）
Future<void> ensureReady(dynamic p2p, void Function(String) log) async {
  log('  权限: 检查存储…');
  if (!await p2p.checkStoragePermission()) await p2p.askStoragePermission();
  log('  权限: 检查 P2P…');
  if (!await p2p.checkP2pPermissions()) await p2p.askP2pPermissions();
  log('  权限: 检查蓝牙…');
  if (!await p2p.checkBluetoothPermissions()) {
    await p2p.askBluetoothPermissions();
  }
  log('  服务: 检查 WiFi…');
  if (!await p2p.checkWifiEnabled()) await p2p.enableWifiServices();
  log('  服务: 检查定位…');
  if (!await p2p.checkLocationEnabled()) await p2p.enableLocationServices();
  log('  服务: 检查蓝牙…');
  if (!await p2p.checkBluetoothEnabled()) await p2p.enableBluetoothServices();
  log('  权限/服务检查全部完成');
}

/// 日志区 + 输入区公共壳
class LogView extends StatelessWidget {
  const LogView({
    super.key,
    required this.lines,
    required this.controller,
    required this.onSend,
  });

  final List<String> lines;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            // 倒序：最新日志在顶部，uiautomator dump 才能读到
            itemCount: lines.length,
            itemBuilder: (_, i) {
              final s = lines[lines.length - 1 - i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: Text(s, style: const TextStyle(fontSize: 13)),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: '消息'),
                ),
              ),
              IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Host：建组 + 收发
class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final _host = FlutterP2pHost();
  final _input = TextEditingController();
  final _logs = <String>[];
  HotspotHostState? _state;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _host.initialize();
    var lastHotspot = '';
    _host.streamHotspotState().listen((s) {
      setState(() => _state = s);
      final sig =
          '${s.isActive}/${s.ssid}/${s.hostIpAddress}/${s.failureReason}';
      if (sig == lastHotspot) return;
      lastHotspot = sig;
      _log(
        'hotspot: active=${s.isActive} ssid=${s.ssid} '
        'psk=${s.preSharedKey} ip=${s.hostIpAddress} fail=${s.failureReason}',
      );
    });
    var lastClients = '';
    _host.streamClientList().listen((cs) {
      // 插件会反复推同内容，去重防刷屏（刷屏会把日志顶出可视区）
      final sig = cs.map((c) => c.id).join(',');
      if (sig == lastClients) return;
      lastClients = sig;
      _log('clients: ${cs.map((c) => '${c.username}(${c.id})').join(', ')}');
    });
    _host.streamReceivedTexts().listen((t) => _log('收到: $t'));
  }

  void _log(String s) => setState(() => _logs.add(s));

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOST')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  _log('① 点击建组');
                  try {
                    // 权限已用 pm grant 全授，不再走插件权限检查（会挂死）
                    _log('② 跳过权限检查');
                    final s = await _host.createGroup(advertise: true);
                    _log(
                      '③ createGroup -> ssid=${s.ssid} psk=${s.preSharedKey} '
                      'ip=${s.hostIpAddress} fail=${s.failureReason}',
                    );
                  } catch (e) {
                    _log('❌ 异常: $e');
                  }
                },
                child: const Text('建组'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _host.removeGroup();
                  _log('组已移除');
                },
                child: const Text('解散'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final f = File('${Directory.systemTemp.path}/spike_test.txt');
                  await f.writeAsString('hello from host ${DateTime.now()}');
                  final info = await _host.broadcastFile(f);
                  _log('文件已广播: ${info?.name} id=${info?.id}');
                },
                child: const Text('发文件'),
              ),
            ],
          ),
          if (_state != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'SSID: ${_state!.ssid}\nPSK: ${_state!.preSharedKey}\n'
                'IP: ${_state!.hostIpAddress}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: LogView(
              lines: _logs,
              controller: _input,
              onSend: () async {
                await _host.broadcastText(_input.text);
                _log('我: ${_input.text}');
                _input.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Client：扫描 + 连接 + 收发
class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  final _client = FlutterP2pClient();
  final _input = TextEditingController();
  final _logs = <String>[];
  final _found = <BleDiscoveredDevice>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _client.initialize();
    _client.streamReceivedTexts().listen((t) => _log('收到: $t'));
  }

  void _log(String s) => setState(() => _logs.add(s));

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CLIENT')),
      body: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // 权限已用 pm grant 全授，不再走插件权限检查
                  //（其 checkBluetoothPermissions 在 K80/HyperOS 上会挂死 platform channel）
                  await _client.startScan((devices) {
                    setState(() {
                      _found
                        ..clear()
                        ..addAll(devices);
                    });
                    _log('扫描到 ${devices.length} 台');
                  });
                  _log('扫描中…');
                },
                child: const Text('BLE 扫描'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _client.stopScan();
                  _log('扫描停止');
                },
                child: const Text('停止'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _client.disconnect();
                  _log('已断开');
                },
                child: const Text('断开'),
              ),
            ],
          ),
          // 发现列表：点击即连接
          SizedBox(
            height: 120,
            child: ListView.builder(
              itemCount: _found.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                title: Text(
                  _found[i].deviceName,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  _found[i].deviceAddress,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  _log('连接 ${_found[i].deviceName}…');
                  await _client.connectWithDevice(_found[i]);
                  _log('连接完成');
                },
              ),
            ),
          ),
          Expanded(
            child: LogView(
              lines: _logs,
              controller: _input,
              onSend: () async {
                await _client.broadcastText(_input.text);
                _log('我: ${_input.text}');
                _input.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}

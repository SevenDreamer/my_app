//! 双机延迟测量：UDP 对时（NTP 式）+ 心跳节拍配对
//!
//! 控制端 [LatencyProbe]：周期心跳的节拍时间戳广播 + 对时应答；
//! 被控端 [LatencyMeter]：收节拍、对时算两机时钟差、与手柄按键事件配对，
//! 得出「按下 → 收到」的端到端延迟。纯 dart:io，无需三方包。
//!
//! 配对防错位：心跳偶数拍 = 按下(Down)、奇数拍 = 抬起(Up)——事件按
//! 奇偶性找节拍；超过 [kBeatTtlMs] 未配对的节拍计丢包回收，
//! 丢一个报告不会让后续样本整体错位。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 被控端监听端口（对时请求也发到这里）
const int kLatencyPort = 45123;

/// 心跳周期——不宜过快：采样密了统计抖，且 TTL 不变量（< 两倍周期）
/// 会把可用的迟到样本窗口压得太小
const Duration kBeatInterval = Duration(milliseconds: 200);

/// 节拍未配对存活窗口（超过计丢包）。
/// 防错位不变量：必须小于心跳周期的两倍（400ms）——同一奇偶的相邻
/// 节拍间隔 400ms，TTL 在此之前回收旧拍，晚到事件才不会错配到旧拍。
const int kBeatTtlMs = 350;

/// 控制端：心跳节拍广播 + 对时应答
class LatencyProbe {
  RawDatagramSocket? _socket;
  Timer? _helloTimer;
  int _seq = 0;

  Future<void> start() async {
    if (_socket != null) return;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final msg = utf8.decode(dg.data, allowMalformed: true).trim();
      if (msg.startsWith('sync ')) {
        // NTP 式应答：原样带回对方发送时刻 + 收/发时刻（本机时钟）
        final c1 = msg.substring(5);
        final s1 = DateTime.now().millisecondsSinceEpoch;
        socket.send(
          utf8.encode(
              'syncack $c1 $s1 ${DateTime.now().millisecondsSinceEpoch}'),
          dg.address,
          dg.port,
        );
      }
    });
    // hello 广播：让被控端发现控制端地址/端口
    _helloTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _sendHello());
    _sendHello();
  }

  void _sendHello() {
    final socket = _socket;
    if (socket == null) return;
    socket.send(utf8.encode('hello ${socket.port}'),
        InternetAddress('255.255.255.255'), kLatencyPort);
  }

  /// 每个心跳节拍调用一次：广播节拍序号与时间戳（控制端时钟）
  void beat() {
    final socket = _socket;
    if (socket == null) return;
    final seq = _seq++;
    socket.send(
      utf8.encode('beat $seq ${DateTime.now().millisecondsSinceEpoch}'),
      InternetAddress('255.255.255.255'),
      kLatencyPort,
    );
  }

  void stop() {
    _helloTimer?.cancel();
    _helloTimer = null;
    _socket?.close();
    _socket = null;
    _seq = 0;
  }
}

/// 被控端：节拍收集 + 对时 + 按键事件配对
class LatencyMeter {
  LatencyMeter({int Function()? now})
      : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final int Function() _now;

  RawDatagramSocket? _socket;
  Timer? _syncTimer;
  InternetAddress? _controllerAddr;
  int? _controllerPort;

  /// 待配对节拍：seq → (t1 控制端时钟, hostAt 本机收到时刻)
  final _pending = <int, (int, int)>{};

  /// 端到端毫秒样本（上限 100）
  final _latencies = <int>[];
  int _lost = 0;

  /// 时钟差（控制端 - 本机，ms，滑动平均）
  double? _offset;

  bool get running => _socket != null;

  /// 当前统计文案（无样本为 null）
  String? get stats {
    if (_latencies.isEmpty) return null;
    var sum = 0, min = _latencies.first, max = _latencies.first;
    for (final v in _latencies) {
      sum += v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    return '样本 ${_latencies.length} · 平均 ${sum ~/ _latencies.length}ms'
        ' · 波动 ${max - min}ms · 丢包 $_lost';
  }

  Future<void> start() async {
    if (_socket != null) return;
    final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, kLatencyPort,
        reuseAddress: true);
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;
      final msg = utf8.decode(dg.data, allowMalformed: true).trim();
      final parts = msg.split(' ');
      if (parts.length == 2 && parts[0] == 'hello') {
        _controllerAddr = dg.address;
        _controllerPort = int.tryParse(parts[1]);
      } else if (parts.length == 3 && parts[0] == 'beat') {
        final seq = int.tryParse(parts[1]);
        final t1 = int.tryParse(parts[2]);
        if (seq != null && t1 != null) ingestBeat(seq, t1);
      } else if (parts.length == 4 && parts[0] == 'syncack') {
        final c1 = double.tryParse(parts[1]);
        final s1 = double.tryParse(parts[2]);
        final s2 = double.tryParse(parts[3]);
        if (c1 != null && s1 != null && s2 != null) {
          ingestSyncAck(c1, s1, s2, _now().toDouble());
        }
      }
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sync());
    _sync();
  }

  void _sync() {
    final socket = _socket;
    final addr = _controllerAddr;
    final port = _controllerPort;
    if (socket == null || addr == null || port == null) return;
    socket.send(utf8.encode('sync ${_now()}'), addr, port);
  }

  /// 收到一个心跳节拍（socket 层与测试共用入口）
  void ingestBeat(int seq, int t1) {
    _purgeStale();
    _pending[seq] = (t1, _now());
  }

  /// 收到对时应答：θ = ((s1-c1) + (s2-c2)) / 2（NTP 式，假设路径对称）
  void ingestSyncAck(double c1, double s1, double s2, double c2) {
    final theta = ((s1 - c1) + (s2 - c2)) / 2;
    _offset = _offset == null ? theta : _offset! * 0.7 + theta * 0.3;
  }

  /// 按键事件（Down=偶数拍 / Up=奇数拍）与最近节拍配对，产出延迟样本
  void onKeyEvent({required bool down}) {
    _purgeStale();
    final offset = _offset;
    if (offset == null || _pending.isEmpty) return;
    final nowCtl = _now() + offset.round();
    int? matchedSeq;
    for (final seq in _pending.keys) {
      if (seq.isEven == down) {
        matchedSeq = seq;
        break;
      }
    }
    if (matchedSeq == null) return;
    final (t1, _) = _pending.remove(matchedSeq)!;
    final latency = nowCtl - t1;
    if (latency < 0 || latency > kBeatTtlMs) return; // 错位样本丢弃
    _latencies.add(latency);
    if (_latencies.length > 100) _latencies.removeAt(0);
  }

  /// 回收超时未配对节拍——丢包防错位的关键
  void _purgeStale() {
    final now = _now();
    _pending.removeWhere((_, v) {
      if (now - v.$2 > kBeatTtlMs) {
        _lost++;
        return true;
      }
      return false;
    });
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _socket?.close();
    _socket = null;
    _pending.clear();
  }
}

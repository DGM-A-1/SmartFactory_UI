import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../widgets/sf_page.dart';

/// 간단 상태 enum (이 페이지 전용)
enum RobotStatus { disconnected, idle, moving, charging, error }
extension _StatusLabel on RobotStatus {
  String get label => switch (this) {
    RobotStatus.disconnected => '연결 안됨',
    RobotStatus.idle => '대기 중',
    RobotStatus.moving => '이동 중',
    RobotStatus.charging => '충전 중',
    RobotStatus.error => '오류',
  };
}

class RosTestPage extends StatefulWidget {
  const RosTestPage({super.key});

  @override
  State<RosTestPage> createState() => _RosTestPageState();
}

class _RosTestPageState extends State<RosTestPage> {
  // Jetson WS 주소 기본값(수정해서 사용)
  final _urlCtrl = TextEditingController(text: 'ws://100.108.7.35:9090');
  int _robotId = 1;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  bool _opened = false;

  bool _subscribed = false; // /robotX/status
  bool _advertised = false; // /robotX/start

  RobotStatus _lastStatus = RobotStatus.disconnected;
  String _lastRaw = '';
  final List<String> _logs = [];

  // ---------- WebSocket ----------
  Future<void> _open() async {
    if (_opened) return;
    try {
      _ch = WebSocketChannel.connect(Uri.parse(_urlCtrl.text.trim()));
      _sub = _ch!.stream.listen(
        _onEvent,
        onError: (e) {
          _log('[ws error] $e');
          setState(() => _opened = false);
        },
        onDone: () {
          _log('[ws done]');
          setState(() => _opened = false);
        },
      );
      setState(() => _opened = true);
      _log('[ws open] ${_urlCtrl.text}');
    } catch (e) {
      _log('[ws connect fail] $e');
      setState(() => _opened = false);
    }
  }

  Future<void> _close() async {
    await _sub?.cancel();
    await _ch?.sink.close();
    _sub = null;
    _ch = null;
    setState(() {
      _opened = false;
      _subscribed = false;
      _advertised = false;
      _lastStatus = RobotStatus.disconnected;
      _lastRaw = '';
    });
    _log('[ws close]');
  }

  void _send(Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    _logs.add('[->] $json');
    setState(() {});
    _ch?.sink.add(json);
  }

  void _onEvent(dynamic evt) {
    _lastRaw = evt.toString();
    _logs.add('[<-] $_lastRaw');

    // 상태 토픽 수신 파싱
    try {
      final data = jsonDecode(_lastRaw);
      if (data is Map && data['op'] == 'publish' && data['topic'] is String) {
        final topic = data['topic'] as String;
        if (topic == '/robot$_robotId/status') {
          final msg = data['msg'];
          final str =
          (msg is Map && msg['data'] is String) ? (msg['data'] as String) : '';
          setState(() => _lastStatus = _mapStatus(str));
        }
      }
    } catch (_) {}
    setState(() {});
  }

  RobotStatus _mapStatus(String s) {
    switch (s) {
      case 'moving':
        return RobotStatus.moving;
      case 'charging':
        return RobotStatus.charging;
      case 'error':
        return RobotStatus.error;
      case 'idle':
        return RobotStatus.idle;
      default:
        return RobotStatus.idle;
    }
  }

  // ---------- Step actions ----------
  Future<void> _pingRosapi() async {
    await _open();
    final id = 'req_${DateTime.now().millisecondsSinceEpoch}';
    _send({'op': 'call_service', 'service': '/rosapi/get_time', 'args': {}, 'id': id});
  }

  Future<void> _subscribeStatus() async {
    await _open();
    _send({
      'op': 'subscribe',
      'topic': '/robot$_robotId/status',
      'type': 'std_msgs/String', // ✅ 타입 명시 중요
      'throttle_rate': 0,
      'queue_length': 1,
    });
    setState(() => _subscribed = true);
  }

  Future<void> _advertiseStart() async {
    await _open();
    _send({
      'op': 'advertise',
      'topic': '/robot$_robotId/start',
      'type': 'std_msgs/Bool',
      'latch': false,
      'queue_size': 1,
    });
    setState(() => _advertised = true);
  }

  Future<void> _publishStart() async {
    await _open();
    _send({
      'op': 'publish',
      'topic': '/robot$_robotId/start',
      'msg': {'data': true},
    });
  }

  Future<void> _unsubscribe() async {
    if (!_subscribed) return;
    _send({'op': 'unsubscribe', 'topic': '/robot$_robotId/status'});
    setState(() => _subscribed = false);
  }

  Future<void> _unadvertise() async {
    if (!_advertised) return;
    _send({'op': 'unadvertise', 'topic': '/robot$_robotId/start'});
    setState(() => _advertised = false);
  }

  void _log(String s) {
    _logs.add(s);
    setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ch?.sink.close();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: 'ROS 연결 테스트',
      // DropdownButton 등 Material 위젯을 위해 Material로 감싸기
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL + 로봇 선택 (오버플로우 방지: Dropdown 고정폭)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        labelText: 'ROS WS URL (예: ws://100.108.7.35:9090)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _robotId,
                        isExpanded: true,
                        onChanged: (v) => setState(() => _robotId = v ?? 1),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('로봇 1')),
                          DropdownMenuItem(value: 2, child: Text('로봇 2')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 연결/핑/닫기 (Wrap으로 자동 줄바꿈)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _opened ? null : _open,
                    child: const Text('1) 연결 열기'),
                  ),
                  OutlinedButton(
                    onPressed: _opened ? _pingRosapi : null,
                    child: const Text('2) rosapi ping'),
                  ),
                  Text(
                    _opened ? 'WS: OPEN' : 'WS: CLOSED',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _opened ? Colors.green : Colors.red,
                    ),
                  ),
                  TextButton(
                    onPressed: _opened ? _close : null,
                    child: const Text('연결 닫기'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 구독/광고/발행 (Wrap으로 자동 줄바꿈)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _opened && !_subscribed ? _subscribeStatus : null,
                    child: const Text('3) /로봇 연결'),
                  ),
                  ElevatedButton(
                    onPressed: _opened && !_advertised ? _advertiseStart : null,
                    child: const Text('4) /start 신호 보내기'),
                  ),
                  ElevatedButton(
                    onPressed: _opened && _advertised ? _publishStart : null,
                    child: const Text('5) 호출 Publish'),
                  ),
                  OutlinedButton(
                    onPressed: _subscribed ? _unsubscribe : null,
                    child: const Text('구독 해제'),
                  ),
                  OutlinedButton(
                    onPressed: _advertised ? _unadvertise : null,
                    child: const Text('출발 신호 해제'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 현재 상태
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: switch (_lastStatus) {
                          RobotStatus.disconnected => Colors.grey,
                          RobotStatus.idle => Colors.green,
                          RobotStatus.moving => Colors.blue,
                          RobotStatus.charging => Colors.orange,
                          RobotStatus.error => Colors.red,
                        },
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '로봇$_robotId 상태: ${_lastStatus.label}',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Text('최근 수신 RAW', style: TextStyle(fontWeight: FontWeight.w700)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _lastRaw.isEmpty ? '(수신 없음)' : _lastRaw,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),

              const Text('로그', style: TextStyle(fontWeight: FontWeight.w700)),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Text(
                      _logs[i],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

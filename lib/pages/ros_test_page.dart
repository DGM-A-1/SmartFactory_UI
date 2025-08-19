import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/sf_page.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 테스트 페이지 전용 상태(세분화 포함)
enum RobotStatus {
  disconnected,
  idle,
  toLoading,        // 상차 위치 이동 중
  loadingWait,      // 무게 대기 중
  toDestination,    // 도착지 이동 중
  unloadingWait,    // 하역 대기 중
  returning,        // 복귀 중
  moving,           // 호환
  charging,
  error,
}

extension _StatusLabel on RobotStatus {
  String get label {
    switch (this) {
      case RobotStatus.disconnected: return '연결 안됨';
      case RobotStatus.idle:         return '대기 중';
      case RobotStatus.toLoading:    return '상차 위치 이동 중';
      case RobotStatus.loadingWait:  return '무게 대기 중';
      case RobotStatus.toDestination:return '도착지 이동 중';
      case RobotStatus.unloadingWait:return '하역 대기 중';
      case RobotStatus.returning:    return '복귀 중';
      case RobotStatus.moving:       return '이동 중';
      case RobotStatus.charging:     return '충전 중';
      case RobotStatus.error:        return '오류';
    }
  }

  Color get color {
    switch (this) {
      case RobotStatus.disconnected: return Colors.grey;
      case RobotStatus.idle:         return Colors.green;
      case RobotStatus.toLoading:
      case RobotStatus.toDestination:
      case RobotStatus.returning:
      case RobotStatus.moving:       return Colors.blue;
      case RobotStatus.loadingWait:
      case RobotStatus.unloadingWait:
      case RobotStatus.charging:     return Colors.orange;
      case RobotStatus.error:        return Colors.red;
    }
  }
}

class RosTestPage extends StatefulWidget {
  const RosTestPage({super.key});
  @override
  State<RosTestPage> createState() => _RosTestPageState();
}

class _RosTestPageState extends State<RosTestPage> {
  // Jetson rosbridge 주소(수정 가능)
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
    // 정리: 구독/광고 해제
    if (_subscribed) {
      _send({'op': 'unsubscribe', 'topic': '/robot$_robotId/status'});
      _subscribed = false;
    }
    if (_advertised) {
      _send({'op': 'unadvertise', 'topic': '/robot$_robotId/start'});
      _advertised = false;
    }
    await _sub?.cancel();
    await _ch?.sink.close();
    _sub = null;
    _ch = null;

    setState(() {
      _opened = false;
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

    try {
      final data = jsonDecode(_lastRaw);
      if (data is Map && data['op'] == 'publish' && data['topic'] is String) {
        final topic = data['topic'] as String;
        if (topic == '/robot$_robotId/status') {
          final msg = data['msg'];
          final str = (msg is Map && msg['data'] is String)
              ? (msg['data'] as String).toLowerCase()
              : '';
          setState(() => _lastStatus = _mapStatus(str));
        }
      }
    } catch (_) {}
    setState(() {});
  }

  RobotStatus _mapStatus(String s) {
    switch (s) {
      case 'to_loading':     return RobotStatus.toLoading;
      case 'loading_wait':   return RobotStatus.loadingWait;
      case 'to_destination': return RobotStatus.toDestination;
      case 'unloading_wait': return RobotStatus.unloadingWait;
      case 'returning':      return RobotStatus.returning;
      case 'moving':         return RobotStatus.moving;
      case 'charging':       return RobotStatus.charging;
      case 'error':          return RobotStatus.error;
      case 'idle':
      default:               return RobotStatus.idle;
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
      'type': 'std_msgs/String', // ✅ 타입 명시
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
      'type': 'std_msgs/Bool',    // ✅ Bool
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
      child: Material( // Dropdown 등을 위해 Material 컨텍스트 제공
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL + 로봇 선택
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

              // 연결/핑/닫기
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

              // 구독/광고/발행
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _opened && !_subscribed ? _subscribeStatus : null,
                    child: const Text('3) /status 구독'),
                  ),
                  ElevatedButton(
                    onPressed: _opened && !_advertised ? _advertiseStart : null,
                    child: const Text('4) /start 광고'),
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
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _lastStatus.color,
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

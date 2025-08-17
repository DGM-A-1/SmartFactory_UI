import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../pages/robot_call_page.dart'; // RobotStatus enum 재사용

class RosbridgeComm implements RobotCommAdapter {
  RosbridgeComm({required this.url});
  final String url;

  WebSocketChannel? _ch;
  StreamSubscription? _wsSub;
  bool _opened = false;

  // 로봇별 상태 스트림
  final _statusCtrls = <int, StreamController<RobotStatus>>{
    1: StreamController.broadcast(),
    2: StreamController.broadcast(),
  };

  // 구독 여부 캐시
  final _subscribed = <int, bool>{1: false, 2: false};
  final _advertised = <int, bool>{1: false, 2: false};

  Future<void> _ensureOpen() async {
    if (_opened) return;
    _ch = WebSocketChannel.connect(Uri.parse(url));
    _wsSub = _ch!.stream.listen(_onEvent, onError: (_) {
      _opened = false;
    }, onDone: () {
      _opened = false;
    });
    _opened = true;
  }

  void _onEvent(dynamic evt) {
    try {
      print('[rosbridge<-] $evt');
      final data = jsonDecode(evt as String);
      if (data is! Map) return;
      final op = data['op'];
      if (op == 'publish') {
        final topic = data['topic'] as String? ?? '';
        final msg = data['msg'];

        int? rid;
        if (topic.contains('/robot1/status')) rid = 1;
        if (topic.contains('/robot2/status')) rid = 2;
        if (rid != null) {
          final s = _parseStatus(msg);
          _statusCtrls[rid]!.add(s);
        }
      }
      // call_service 응답 등은 필요 시 처리
    } catch (_) {}
  }

  RobotStatus _parseStatus(dynamic msg) {
    // std_msgs/String: { "data": "idle" }
    final str = (msg is Map && msg['data'] is String) ? msg['data'] as String : 'idle';
    switch (str) {
      case 'moving': return RobotStatus.moving;
      case 'charging': return RobotStatus.charging;
      case 'error':   return RobotStatus.error;
      default:        return RobotStatus.idle;
    }
  }

  void _send(Map<String, dynamic> payload) {
    print('[rosbridge->] ${jsonEncode(payload)}');
    if (_opened) _ch!.sink.add(jsonEncode(payload));
  }

  // --- RobotCommAdapter 구현 ---

  @override
  Future<bool> connectRobot(int robotId) async {
    await _ensureOpen();

    // 상태 토픽 구독 (라치 권장)
    if (_subscribed[robotId] != true) {
      _send({'op': 'subscribe', 'topic': '/robot$robotId/status', 'throttle_rate': 0});
      _subscribed[robotId] = true;
    }

    // 시작 명령 토픽 광고(발행 준비)
    if (_advertised[robotId] != true) {
      _send({
        'op': 'advertise',
        'topic': '/robot$robotId/start',
        'type': 'std_msgs/String',
        'latch': false,
        'queue_size': 1,
      });
      _advertised[robotId] = true;
    }

    // 라치가 없다면 초깃값이 안 오니 UI가 곧장 '대기 중'을 원한다면 임시로 idle 푸시:
    // _statusCtrls[robotId]!.add(RobotStatus.idle);

    return true;
  }

  @override
  Future<void> disconnectRobot(int robotId) async {
    if (_subscribed[robotId] == true) {
      _send({'op': 'unsubscribe', 'topic': '/robot$robotId/status'});
      _subscribed[robotId] = false;
    }
    // 필요하면 unadvertise
    // _send({'op':'unadvertise','topic':'/robot$robotId/start'});
    _statusCtrls[robotId]!.add(RobotStatus.disconnected);
  }

  @override
  Future<bool> sendStart(int robotId) async {
    if (!_opened) return false;
    _send({
      'op': 'publish',
      'topic': '/robot$robotId/start',
      'msg': {'data': true}
    });
    return true;
  }

  @override
  Future<RobotStatus> fetchStatus(int robotId) async {
    // rosbridge엔 "get last"가 없으므로 라치가 없으면 확인 불가.
    // 필요하면 /get_status 같은 ROS service를 만들어 call_service로 가져오세요.
    return RobotStatus.disconnected;
  }

  @override
  Stream<RobotStatus> watchStatus(int robotId) => _statusCtrls[robotId]!.stream;

  // 정리
  Future<void> dispose() async {
    await _wsSub?.cancel();
    await _ch?.sink.close();
    for (final c in _statusCtrls.values) { await c.close(); }
  }
}

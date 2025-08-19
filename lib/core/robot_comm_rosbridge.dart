import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../pages/robot_call_page.dart' show RobotStatus, RobotCommAdapter;

class RosbridgeComm implements RobotCommAdapter {
  RosbridgeComm({required this.url});
  final String url;

  WebSocketChannel? _ch;
  StreamSubscription? _wsSub;
  bool _opened = false;

  // 구독/광고 플래그
  final Map<int, bool> _subscribed = {1: false, 2: false};
  final Map<int, bool> _advertised = {1: false, 2: false};

  // 상태 스트림/캐시
  final _statusCtrls = <int, StreamController<RobotStatus>>{
    1: StreamController<RobotStatus>.broadcast(),
    2: StreamController<RobotStatus>.broadcast(),
  };
  final _last = <int, RobotStatus>{
    1: RobotStatus.disconnected,
    2: RobotStatus.disconnected,
  };

  // ---------- 내부 유틸 ----------
  Future<void> _ensureOpen() async {
    if (_opened) return;
    _ch = WebSocketChannel.connect(Uri.parse(url));
    _wsSub = _ch!.stream.listen(
      _onEvent,
      onDone: () {
        _opened = false;
        _push(1, RobotStatus.disconnected);
        _push(2, RobotStatus.disconnected);
      },
      onError: (_) {
        _opened = false;
        _push(1, RobotStatus.disconnected);
        _push(2, RobotStatus.disconnected);
      },
    );
    _opened = true;
  }

  void _send(Map<String, dynamic> m) {
    final js = jsonEncode(m);
    if (kDebugMode) print('[rosbridge->] $js');
    if (_opened) _ch!.sink.add(js);
  }

  void _onEvent(dynamic evt) {
    if (kDebugMode) print('[rosbridge<-] $evt');
    try {
      final m = jsonDecode(evt as String);
      if (m is! Map) return;
      if (m['op'] == 'publish' && m['topic'] is String) {
        final topic = m['topic'] as String;
        // /robot{n}/status 매칭
        final reg = RegExp(r'^/robot(\d+)/status$');
        final match = reg.firstMatch(topic);
        if (match != null) {
          final rid = int.tryParse(match.group(1) ?? '') ?? 1;
          final msg = m['msg'];
          final s = _parseStatus(msg);
          _push(rid, s);
        }
      }
    } catch (_) {}
  }

  void _push(int rid, RobotStatus s) {
    _last[rid] = s;
    _statusCtrls[rid]?.add(s);
  }

  RobotStatus _parseStatus(dynamic msg) {
    final str = (msg is Map && msg['data'] is String)
        ? (msg['data'] as String).toLowerCase()
        : 'idle';
    switch (str) {
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

  // ---------- RobotCommAdapter 구현 ----------
  @override
  Future<bool> connectRobot(int robotId) async {
    await _ensureOpen();

    // 1) 상태 구독 (type 반드시 명시)
    if (_subscribed[robotId] != true) {
      _send({
        'op': 'subscribe',
        'topic': '/robot$robotId/status',
        'type': 'std_msgs/String',
        'throttle_rate': 0,
        'queue_length': 1,
      });
      _subscribed[robotId] = true;
    }

    // 2) 시작 토픽 광고 (Bool)
    if (_advertised[robotId] != true) {
      _send({
        'op': 'advertise',
        'topic': '/robot$robotId/start',
        'type': 'std_msgs/Bool',
        'latch': false,
        'queue_size': 1,
      });
      _advertised[robotId] = true;
    }

    // 3) UI 즉시 업데이트(라치가 곧바로 덮어씀)
    _push(robotId, RobotStatus.idle);

    return true;
  }

  @override
  Future<void> disconnectRobot(int robotId) async {
    if (_subscribed[robotId] == true) {
      _send({'op': 'unsubscribe', 'topic': '/robot$robotId/status'});
      _subscribed[robotId] = false;
    }
    if (_advertised[robotId] == true) {
      _send({'op': 'unadvertise', 'topic': '/robot$robotId/start'});
      _advertised[robotId] = false;
    }
    _push(robotId, RobotStatus.disconnected);
  }

  @override
  Future<bool> sendStart(int robotId) async {
    if (!_opened) return false;
    _send({
      'op': 'publish',
      'topic': '/robot$robotId/start',
      'msg': {'data': true},
    });
    return true;
  }

  @override
  Future<RobotStatus> fetchStatus(int robotId) async {
    return _last[robotId] ?? RobotStatus.disconnected;
  }

  @override
  Stream<RobotStatus> watchStatus(int robotId) {
    return _statusCtrls[robotId]!.stream;
  }

  // 선택: 전체 해제
  Future<void> dispose() async {
    await _wsSub?.cancel();
    await _ch?.sink.close();
    for (final c in _statusCtrls.values) { await c.close(); }
  }
}

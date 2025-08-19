import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartfactory_ui/core/app_config.dart';
import '../core/robot_comm_rosbridge.dart';
import '../widgets/sf_page.dart';

// ---- 상태/모델 ----
enum RobotStatus {
  disconnected,
  idle,
  toLoading,        // 상차 위치 이동 중
  loadingWait,      // 무게 대기 중
  toDestination,    // 도착지 이동 중
  unloadingWait,    // 하역 대기 중
  returning,        // 복귀 중
  moving,           // (기존 호환)
  charging,
  error,
}

extension RobotStatusText on RobotStatus {
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
}

class RobotState {
  RobotState({required this.id, required RobotStatus status})
      : status = ValueNotifier<RobotStatus>(status);

  final int id; // 1 or 2
  final ValueNotifier<RobotStatus> status;
}

// ---- 통신 어댑터 인터페이스 ----
abstract class RobotCommAdapter {
  /// 로봇별 연결 시도 (성공 시 true)
  Future<bool> connectRobot(int robotId);

  /// 필요 시 연결 해제
  Future<void> disconnectRobot(int robotId);

  /// 출발 신호
  Future<bool> sendStart(int robotId);

  /// 현재 상태 1회 조회(연결 안되어 있으면 disconnected로)
  Future<RobotStatus> fetchStatus(int robotId);

  /// 상태 스트림(연결 이후에만 의미 있음)
  Stream<RobotStatus> watchStatus(int robotId);
}

// ---- 임시 더미 구현 ----
class DummyRobotComm implements RobotCommAdapter {
  final _controllers = <int, StreamController<RobotStatus>>{
    1: StreamController.broadcast(),
    2: StreamController.broadcast(),
  };
  final _status = <int, RobotStatus>{
    1: RobotStatus.disconnected,
    2: RobotStatus.disconnected
  };
  final _connected = <int, bool>{1: false, 2: false};

  @override
  Future<bool> connectRobot(int robotId) async {
    // 더미: 1초 후 성공, 상태를 idle로 전환
    await Future.delayed(const Duration(seconds: 1));
    _connected[robotId] = true;
    _push(robotId, RobotStatus.idle);
    return true;
  }

  @override
  Future<void> disconnectRobot(int robotId) async {
    _connected[robotId] = false;
    _push(robotId, RobotStatus.disconnected);
  }

  @override
  Future<bool> sendStart(int robotId) async {
    if (_connected[robotId] != true) return false;
    _push(robotId, RobotStatus.moving);
    await Future.delayed(const Duration(seconds: 2));
    _push(robotId, RobotStatus.idle);
    return true;
  }

  @override
  Future<RobotStatus> fetchStatus(int robotId) async {
    return _status[robotId] ?? RobotStatus.disconnected;
  }

  @override
  Stream<RobotStatus> watchStatus(int robotId) {
    return _controllers[robotId]!.stream;
  }

  void _push(int robotId, RobotStatus s) {
    _status[robotId] = s;
    _controllers[robotId]!.add(s);
  }
}

// ---- 페이지 ----
class RobotCallPage extends StatefulWidget {
  const RobotCallPage({super.key});

  @override
  State<RobotCallPage> createState() => _RobotCallPageState();
}

class _RobotCallPageState extends State<RobotCallPage> {
  late final RobotCommAdapter _comm;
  final RobotState _robot1 = RobotState(
      id: 1, status: RobotStatus.disconnected);
  final RobotState _robot2 = RobotState(
      id: 2, status: RobotStatus.disconnected);
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  final GlobalKey<ScaffoldMessengerState> _smKey = GlobalKey<
      ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final url = AppConfig.I.rosWsUrl.value;
    _comm = RosbridgeComm(url: url);
    _bootstrap();
  }

  void _snack(String msg) {
    _smKey.currentState?.hideCurrentSnackBar();
    _smKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _bootstrap() async {
    // 초기 상태 동기화 (연결 안됨이 기본)
    _robot1.status.value = await _comm.fetchStatus(1);
    _robot2.status.value = await _comm.fetchStatus(2);
    // 스트림은 연결 이후에 구독(연결 버튼 시)
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    super.dispose();
  }

  Future<void> _connectRobot(int robotId) async {
    // 1) 상태 리스너를 먼저 단다 (이미 있으면 재사용)
    if (robotId == 1 && _sub1 == null)   {
      _sub1 = _comm.watchStatus(1).listen((s) {
        if (!mounted) return;
        _robot1.status.value = s;
      });
    } else if (robotId == 2 && _sub2 == null) {
      _sub2 = _comm.watchStatus(2).listen((s) {
        if (!mounted) return;
        _robot2.status.value = s;
      });
    }

    // 2) 실제 연결 (subscribe/advertise 전송)
    final ok = await _comm.connectRobot(robotId);
    if (!mounted) return;
    _snack(ok ? '로봇$robotId 연결 성공' : '로봇$robotId 연결 실패');
  }


  Future<void> _callRobot(int robotId) async {
    final ok = await _comm.sendStart(robotId);
    if (!mounted) return;
    final msg = ok ? '로봇$robotId 출발 신호 전송 완료' : '로봇$robotId가 연결되지 않았습니다';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '로봇 호출',
      child: ScaffoldMessenger( // ✅ 로컬 Messenger
        key: _smKey,
        child: Scaffold( // ✅ 로컬 Scaffold
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MapCard(),
                const SizedBox(height: 8),
                const _Legend(),
                const SizedBox(height: 12),
                _CallButtons(
                  onCall1: () => _callRobot(1),
                  onCall2: () => _callRobot(2),
                ),
                const SizedBox(height: 16),
                _StatusBlock(
                  title: '로봇1 상태',
                  statusListenable: _robot1.status,
                  onConnect: () => _connectRobot(1),
                ),
                const SizedBox(height: 16),
                _StatusBlock(
                  title: '로봇2 상태',
                  statusListenable: _robot2.status,
                  onConnect: () => _connectRobot(2),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- UI 위젯들 ---
class _MapCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white, // 흰색 배경 유지
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 카드의 가용 너비를 기준으로, 좀 더 키 큰 비율로 영역을 넓게 잡음
          // (4:3보다 세로를 조금 더 주어, 흰 영역을 빵빵하게 채움)
          const aspect = 3 / 2; // 필요하면 3/2, 4/3 등으로 미세 조정 가능
          final height = constraints.maxWidth / aspect;

          return SizedBox(
            width: double.infinity,
            height: height,
            child: Padding(
              // 내부 여백 최소화해서 거의 가득 차게
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: Image.asset(
                  'assets/images/floor_map.png',
                  fit: BoxFit.contain, // 이미지 전체가 보이도록(잘림 방지)
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LegendRow(color: Color(0xFF7A5C45), label: '로봇 1'),
        SizedBox(height: 15), // 행 간격 작게
        _LegendRow(color: Color(0xFF6B7280), label: '로봇 2'),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CallButtons extends StatelessWidget {
  const _CallButtons({required this.onCall1, required this.onCall2});
  final VoidCallback onCall1;
  final VoidCallback onCall2;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(24),
            onPressed: onCall1,
            child: const Text('로봇1 호출', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(24),
            onPressed: onCall2,
            child: const Text('로봇2 호출', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.title,
    required this.statusListenable,
    required this.onConnect,
  });

  final String title;
  final ValueListenable<RobotStatus> statusListenable;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RobotStatus>(
      valueListenable: statusListenable,
      builder: (_, s, __) {
        final isDisconnected = s == RobotStatus.disconnected;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 연결 버튼
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                // 연결 버튼(슬림)
                SizedBox(
                  height: 36,
                  child: CupertinoButton(
                    minSize: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    borderRadius: BorderRadius.circular(18),
                    color: isDisconnected
                        ? CupertinoColors.systemYellow
                        : CupertinoColors.systemGrey4,
                    onPressed: isDisconnected ? onConnect : null,
                    child: Text(
                      isDisconnected ? '연결' : '연결됨',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // 상태 박스
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  _StatusDot(status: s),
                  const SizedBox(width: 10),
                  Text(
                    s.label,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ],
              ),
            ),

            // ✅ "연결 안됨"일 때만, 상태 박스 '밑에' 테스트 버튼 노출
            if (isDisconnected) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bug_report_outlined, size: 18, color: Colors.black),
                  label: const Text('로봇 연결 테스트', style: TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/ros-test'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final RobotStatus status;

  Color get _color {
    switch (status) {
      case RobotStatus.disconnected:
        return Colors.grey;
      case RobotStatus.idle:
        return Colors.green;
      case RobotStatus.toLoading:
      case RobotStatus.toDestination:
      case RobotStatus.returning:
        return Colors.blue;
      case RobotStatus.loadingWait:
      case RobotStatus.unloadingWait:
        return Colors.orange;
      case RobotStatus.moving:
        return Colors.blue;
      case RobotStatus.charging:
        return Colors.orange;
      case RobotStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(width: 12,
        height: 12,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle));
  }

}
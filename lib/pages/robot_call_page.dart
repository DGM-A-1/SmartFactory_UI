import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/sf_page.dart';

// ---- 상태/모델 ----
enum RobotStatus { idle, moving, charging, error }

extension RobotStatusText on RobotStatus {
  String get label {
    switch (this) {
      case RobotStatus.idle:
        return '대기 중';
      case RobotStatus.moving:
        return '이동 중';
      case RobotStatus.charging:
        return '충전 중';
      case RobotStatus.error:
        return '오류';
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
  Future<void> connect();
  Future<bool> sendStart(int robotId);
  Future<RobotStatus> fetchStatus(int robotId);
  Stream<RobotStatus> watchStatus(int robotId);
  Future<void> dispose();
}

// ---- 임시 더미 구현 ----
class DummyRobotComm implements RobotCommAdapter {
  final _controllers = <int, StreamController<RobotStatus>>{
    1: StreamController.broadcast(),
    2: StreamController.broadcast(),
  };
  final _status = <int, RobotStatus>{1: RobotStatus.idle, 2: RobotStatus.idle};

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
  }

  @override
  Future<bool> sendStart(int robotId) async {
    _push(robotId, RobotStatus.moving);
    await Future.delayed(const Duration(seconds: 3));
    _push(robotId, RobotStatus.idle);
    return true;
  }

  @override
  Future<RobotStatus> fetchStatus(int robotId) async {
    return _status[robotId] ?? RobotStatus.idle;
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
  final RobotState _robot1 = RobotState(id: 1, status: RobotStatus.idle);
  final RobotState _robot2 = RobotState(id: 2, status: RobotStatus.idle);
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;

  @override
  void initState() {
    super.initState();
    _comm = DummyRobotComm(); // 후에 rosbridge/TCP/REST 등으로 교체
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _comm.connect();
    _robot1.status.value = await _comm.fetchStatus(1);
    _robot2.status.value = await _comm.fetchStatus(2);
    _sub1 = _comm.watchStatus(1).listen((s) => _robot1.status.value = s);
    _sub2 = _comm.watchStatus(2).listen((s) => _robot2.status.value = s);
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _comm.dispose();
    super.dispose();
  }

  Future<void> _callRobot(int robotId) async {
    final ok = await _comm.sendStart(robotId);
    if (!mounted) return;
    final msg = ok ? '로봇$robotId 출발 신호 전송 완료' : '로봇$robotId 출발 신호 실패';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '로봇 호출',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MapCard(),                 // 지도 카드: 배경 흰색으로 수정
            const SizedBox(height: 8),
            const _Legend(),            // 범례: 글씨 작게 + 세로(Column)
            const SizedBox(height: 12),
            _CallButtons(
              onCall1: () => _callRobot(1),
              onCall2: () => _callRobot(2),
            ),
            const SizedBox(height: 20),
            _StatusBlock(
              title: '로봇1 상태',
              statusListenable: _robot1.status,
            ),
            const SizedBox(height: 20),
            _StatusBlock(
              title: '로봇2 상태',
              statusListenable: _robot2.status,

            ),
            const SizedBox(height: 32),
          ],
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
      // ✅ 요청: 배경 '흰색'
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Image.asset(
                'assets/images/floor_map.png',
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text(
                    '지도 이미지를 준비해주세요 (assets/floor_map.png)',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  Widget _dot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) {
    // ✅ 요청: 글씨 작게 + 세로(Column) 배치 + 검정색
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            // 로봇 1
            _LegendDotText(
              color: Color(0xFF7A5C45),
              label: '로봇 1',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: const [
            // 로봇 2
            _LegendDotText(
              color: Color(0xFF6B7280),
              label: '로봇 2',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDotText extends StatelessWidget {
  const _LegendDotText({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        const SizedBox.shrink(),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black, // ✅ 검정색
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(24),
            onPressed: onCall1,
            child: const Text(
              '로봇1 호출',
              style: TextStyle(
                color: Colors.black, // ✅ 검정색
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(24),
            onPressed: onCall2,
            child: const Text(
              '로봇2 호출',
              style: TextStyle(
                color: Colors.black, // ✅ 검정색
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.title, required this.statusListenable});
  final String title;
  final ValueListenable<RobotStatus> statusListenable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ 제목도 검정색
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<RobotStatus>(
          valueListenable: statusListenable,
          builder: (_, s, __) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _StatusDot(status: s),
                  const SizedBox(width: 8),
                  Text(
                    s.label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black, // ✅ 검정색
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final RobotStatus status;

  Color get _color {
    switch (status) {
      case RobotStatus.idle:
        return Colors.green;
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
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}

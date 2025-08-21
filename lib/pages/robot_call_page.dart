import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfactory_ui/core/app_config.dart';
import '../core/robot_comm_rosbridge.dart';
import '../widgets/sf_page.dart';

// 아이콘 에셋 경로(범례/지도 공용)
const String kIconAmr        = 'assets/images/robot_amr.png';
const String kIconAmrLoaded  = 'assets/images/robot_amr_loaded.png';

// ---- 상태/모델 ----
enum RobotStatus {
  disconnected,
  idle,
  toLoading,        // 상차 위치 이동 중
  loadingWait,      // 무게 대기 중
  toStopover,       // 목적지 대기
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
      case RobotStatus.toStopover:   return '경유지(P2) 이동/대기';
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
  Future<bool> connectRobot(int robotId);
  Future<void> disconnectRobot(int robotId);
  Future<bool> sendStart(int robotId);
  Future<RobotStatus> fetchStatus(int robotId);
  Stream<RobotStatus> watchStatus(int robotId);
}

// ---- 페이지 ----
class RobotCallPage extends StatefulWidget {
  const RobotCallPage({super.key});

  @override
  State<RobotCallPage> createState() => _RobotCallPageState();
}

class _RobotCallPageState extends State<RobotCallPage> {
  late final RobotCommAdapter _comm;
  final RobotState _robot1 = RobotState(id: 1, status: RobotStatus.disconnected);
  final RobotState _robot2 = RobotState(id: 2, status: RobotStatus.disconnected);
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  final GlobalKey<ScaffoldMessengerState> _smKey = GlobalKey<ScaffoldMessengerState>();

  // 디버그용: 앵커 점 보이기
  bool _showGuides = false;

  @override
  void initState() {
    super.initState();
    final url = AppConfig.I.rosWsUrl.value;
    _comm = RosbridgeComm(url: url); // ✅ 이미 구현돼 있는 ROSBridge 어댑터
    _bootstrap();
  }

  void _snack(String msg) {
    _smKey.currentState?.hideCurrentSnackBar();
    _smKey.currentState?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _bootstrap() async {
    // ✅ 앱 시작 시 1회 상태 조회
    _robot1.status.value = await _comm.fetchStatus(1);
    _robot2.status.value = await _comm.fetchStatus(2);
    // 스트림은 실제 연결 후 구독
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    super.dispose();
  }

  Future<void> _connectRobot(int robotId) async {
    // 1) 상태 스트림 구독(한 번만)
    if (robotId == 1 && _sub1 == null) {
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

    // 2) ROSBridge 연결 요청
    final ok = await _comm.connectRobot(robotId);
    if (!mounted) return;
    _snack(ok ? '로봇$robotId 연결 성공' : '로봇$robotId 연결 실패');
  }

  Future<void> _callRobot(int robotId) async {
    // ✅ 출발 신호만 보냄. 실제 아이콘 위치는 ROS가 보내는 상태값으로 자동 갱신됨.
    final ok = await _comm.sendStart(robotId);
    if (!mounted) return;
    final msg = ok ? '로봇$robotId 출발 신호 전송 완료' : '로봇$robotId가 연결되지 않았습니다';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '로봇 호출',
      child: ScaffoldMessenger(
        key: _smKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ 지도 + 로봇 아이콘 캔버스
                _MapCanvas(
                  status1: _robot1.status,
                  status2: _robot2.status,
                  showGuides: _showGuides,
                ),
                const SizedBox(height: 8),
                const _Legend(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(24),
                        onPressed: () => _callRobot(1),
                        child: const Text('로봇1 호출',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(24),
                        onPressed: () => _callRobot(2),
                        child: const Text('로봇2 호출',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 디버그 토글
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(20),
                      onPressed: () => setState(() => _showGuides = !_showGuides),
                      child: Text(_showGuides ? '가이드 OFF' : '가이드 ON',
                          style: const TextStyle(color: Colors.black)),
                    ),
                  ],
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

/// ---------------------------------------------------------------------------
/// 지도 위에 로봇 아이콘을 얹는 캔버스
/// ---------------------------------------------------------------------------
class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.status1,
    required this.status2,
    this.showGuides = false,
  });

  final ValueListenable<RobotStatus> status1;
  final ValueListenable<RobotStatus> status2;
  final bool showGuides;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  static const _mapAsset = 'assets/images/floor_map.png';
  static const _kHomeKey = 'map.home';
  static const _kP1Key   = 'map.p1';
  static const _kP2Key   = 'map.p2';
  static const _kP3Key   = 'map.p3';
  Size? _imgSize;

  // 아이콘 경로
  static const _iconEmpty  = 'assets/images/robot_amr.png';
  static const _iconLoaded = 'assets/images/robot_amr_loaded.png';

  // 정규화 좌표(0~1) — 드래그/탭으로 조정
  Offset _home = const Offset(0.90, 0.87);
  Offset _p1   = const Offset(0.12, 0.87);
  Offset _p2   = const Offset(0.51, 0.24);
  Offset _p3   = const Offset(0.90, 0.20);

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
    _loadAnchors();
  }

  void _loadAnchors() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _home = _readOffset(sp, _kHomeKey, _home);
      _p1   = _readOffset(sp, _kP1Key,   _p1);
      _p2   = _readOffset(sp, _kP2Key,   _p2);
      _p3   = _readOffset(sp, _kP3Key,   _p3);
    });
  }

  bool _isLoadedPhase(RobotStatus s) {
    // toStopover ~ unloadingWait 구간은 짐 실은 AMR
    switch (s) {
      case RobotStatus.toStopover:
      case RobotStatus.toDestination:
      case RobotStatus.unloadingWait:
        return true;
      default:
        return false;
    }
  }

  Widget _robotSpriteAt(
      Offset p, {
        required int robotNo,
        required RobotStatus status,
        double size = 28, // 아이콘 크기 (원하시면 조절)
      }) {
    final asset = _isLoadedPhase(status) ? _iconLoaded : _iconEmpty;
    final tint  = (robotNo == 1)
        ? const Color(0xFF7A5C45) // 로봇1: 갈색
        : const Color(0xFF6B7280); // 로봇2: 회색

    return Positioned(
      left: p.dx - size / 2,
      top:  p.dy - size / 2,
      child: SizedBox(
        width: size, height: size,
        child: Image.asset(
          asset,
          // 아이콘이 단색/모노톤 PNG라면 tint 적용이 깔끔합니다.
          // 컬러 PNG라면 아래 color 줄을 지워주세요.
          color: tint,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, __, ___) {
            // 에셋이 아직 없을 때 임시 원형으로 fallback
            return Container(
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            );
          },
        ),
      ),
    );
  }

  Offset _readOffset(SharedPreferences sp, String key, Offset fallback) {
    final x = sp.getDouble('$key.x');
    final y = sp.getDouble('$key.y');
    if (x == null || y == null) return fallback;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  Future<void> _saveAnchor(String key, Offset v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('$key.x', v.dx);
    await sp.setDouble('$key.y', v.dy);
  }
  void _resolveImageSize() {
    final img = AssetImage(_mapAsset).resolve(const ImageConfiguration());
    ImageStreamListener? l;
    l = ImageStreamListener((info, _) {
      _imgSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
      setState(() {});
      img.removeListener(l!);
    }, onError: (_, __) {
      setState(() {});
      img.removeListener(l!);
    });
    img.addListener(l);
  }

  Offset _mid(Offset a, Offset b, [double t = 0.5]) => Offset.lerp(a, b, t)!;

  Offset? _anchorFor(RobotStatus s) {
    switch (s) {
      case RobotStatus.disconnected: return null;
      case RobotStatus.idle:          return _home;
      case RobotStatus.toLoading:     return _mid(_home, _p1);
      case RobotStatus.loadingWait:   return _p1;
      case RobotStatus.toStopover:    return _p2;
      case RobotStatus.toDestination: return _mid(_p2, _p3);
      case RobotStatus.unloadingWait: return _p3;
      case RobotStatus.returning:     return _mid(_p3, _home);
      case RobotStatus.moving:
      case RobotStatus.charging:
      case RobotStatus.error:
        return _home;
    }
  }

  Offset? _toPixels(Offset? norm, Size size) =>
      norm == null ? null : Offset(norm.dx * size.width, norm.dy * size.height);

  void _probeTap(Offset local, Size size) {
    final norm = Offset(local.dx / size.width, local.dy / size.height);
    final text =
        '좌표: (${norm.dx.toStringAsFixed(4)}, ${norm.dy.toStringAsFixed(4)})';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$text  (복사됨)')),
    );
    // ignore: avoid_print
    print(text);
  }

  Widget _draggableGuide({
    required Size size,
    required Offset norm,
    required ValueChanged<Offset> onChanged,
    required String label,
    required String prefKey,
  }) {
    final p = _toPixels(norm, size)!;
    return Positioned(
      left: p.dx - 5,
      top:  p.dy - 5,
      child: GestureDetector(
        onPanUpdate: (d) {
          final nx = (norm.dx + d.delta.dx / size.width).clamp(0.0, 1.0);
          final ny = (norm.dy + d.delta.dy / size.height).clamp(0.0, 1.0);
          final v = Offset(nx, ny);
          onChanged(v);
          _saveAnchor(prefKey, v);
        },
        child: Column(
          children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(label, style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aspect = (_imgSize != null) ? _imgSize!.width / _imgSize!.height : 1.0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
      child: LayoutBuilder(
        builder: (context, c) {
          final height = c.maxWidth / aspect;
          final size = Size(c.maxWidth, height);

          return SizedBox(
            width: double.infinity,
            height: height,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) => _probeTap(d.localPosition, size),
              child: Stack(
                children: [
                  // 지도
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: Image.asset(_mapAsset, fit: BoxFit.contain),
                    ),
                  ),

                  // 로봇 1/2 아이콘만 표시 (복도 마스킹 제거됨)
                  ValueListenableBuilder<RobotStatus>(
                    valueListenable: widget.status1,
                    builder: (_, s, __) {
                      final p = _toPixels(_anchorFor(s), size);
                      return p == null
                          ? const SizedBox.shrink()
                          : _robotSpriteAt(p, robotNo: 1, status: s, size: 28);
                    },
                  ),
                  ValueListenableBuilder<RobotStatus>(
                    valueListenable: widget.status2,
                    builder: (_, s, __) {
                      final p = _toPixels(_anchorFor(s), size);
                      final off = p == null ? null : p + const Offset(6, 6); // 살짝 오프셋
                      return off == null
                          ? const SizedBox.shrink()
                          : _robotSpriteAt(off, robotNo: 2, status: s, size: 28);
                    },
                  ),

                  // 가이드 점(좌표 조정 전용)
                  if (widget.showGuides) ...[
                    _draggableGuide(
                      size: size, norm: _home, label: 'HOME', prefKey: _kHomeKey,
                      onChanged: (v) => setState(() => _home = v),
                    ),
                    _draggableGuide(
                      size: size, norm: _p1, label: 'P1', prefKey: _kP1Key,
                      onChanged: (v) => setState(() => _p1 = v),
                    ),
                    _draggableGuide(
                      size: size, norm: _p2, label: 'P2', prefKey: _kP2Key,
                      onChanged: (v) => setState(() => _p2 = v),
                    ),
                    _draggableGuide(
                      size: size, norm: _p3, label: 'P3', prefKey: _kP3Key,
                      onChanged: (v) => setState(() => _p3 = v),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _robotIconAt(Offset p, {required String label, required Color color}) {
    const double sz = 20;
    return Positioned(
      left: p.dx - sz / 2,
      top:  p.dy - sz / 2,
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x33000000))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    );
  }
}


/// 복도(구간) 가이드를 그리는 페인터: 두 점 사이를 굵은 반투명 라인으로 표시
class _CorridorPainter extends CustomPainter {
  _CorridorPainter({
    required this.size,
    required this.segments,
    required this.widthPx,
  });

  final Size size;
  final List<(Offset, Offset)> segments; // (normA, normB)
  final double widthPx;

  @override
  void paint(Canvas canvas, Size _) {
    final paint = Paint()
      ..color = const Color(0x88FFD54F)  // 노랑 반투명
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = widthPx;

    for (final seg in segments) {
      final a = Offset(seg.$1.dx * size.width, seg.$1.dy * size.height);
      final b = Offset(seg.$2.dx * size.width, seg.$2.dy * size.height);
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CorridorPainter old) {
    return old.size != size ||
        old.widthPx != widthPx ||
        old.segments != segments;
  }
}


// --- 범례/상태/버튼 기존 구성 ---
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LegendSpriteRow(asset: kIconAmr, label: 'IMU 미적재'),
        SizedBox(height: 12),
        _LegendSpriteRow(asset: kIconAmrLoaded,  label: 'IMU 적재'),
      ],
    );
  }
}

class _LegendSpriteRow extends StatelessWidget {
  const _LegendSpriteRow({required this.asset, required this.label});
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 아이콘 미리보기(틴트 없이 원본 보여줌)
        Image.asset(asset, width: 20, height: 20,
            errorBuilder: (_, __, ___) => const Icon(Icons.block, size: 18)),
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
                  Text(s.label, style: const TextStyle(fontSize: 14, color: Colors.black)),
                ],
              ),
            ),
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
      case RobotStatus.disconnected: return Colors.grey;
      case RobotStatus.idle:         return Colors.green;
      case RobotStatus.toLoading:
      case RobotStatus.toDestination:
      case RobotStatus.returning:
        return Colors.blue;
      case RobotStatus.loadingWait:
      case RobotStatus.unloadingWait:
        return Colors.orange;
      case RobotStatus.moving:       return Colors.blue;
      case RobotStatus.charging:     return Colors.orange;
      case RobotStatus.error:        return Colors.red;
      case RobotStatus.toStopover:   return Colors.deepPurpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}
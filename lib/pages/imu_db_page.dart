import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartfactory_ui/core/auth.dart'; // AuthService.baseUrl, auth(token)

class ImuDatabasePage extends StatefulWidget {
  const ImuDatabasePage({super.key});

  @override
  State<ImuDatabasePage> createState() => _ImuDatabasePageState();
}

class _ImuDatabasePageState extends State<ImuDatabasePage> {
  bool _loading = true;
  String? _error;
  List<ImuRecord> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tok = auth.value.token;
      final uri = Uri.parse(AuthService.baseUrl).resolve('/imu/list'); // ✅ 서버 엔드포인트 맞추면 됨
      final res = await http.get(
        uri,
        headers: {
          if (tok != null) 'X-Auth-Token': tok,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        setState(() {
          _error = '(${res.statusCode}) ${res.body}';
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final List list = data['items'] as List;
      final items = list.map((e) => ImuRecord.fromJson(e as Map<String, dynamic>)).toList();

      // 시리얼 기준 오름차순 정렬
      items.sort((a, b) {
        final ai = int.tryParse(a.code) ?? 0;
        final bi = int.tryParse(b.code) ?? 0;
        return ai.compareTo(bi);
      });

      setState(() {
        _items = items.cast<ImuRecord>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final passCount = _items.where((e) => e.passed).length;
    final failCount = _items.length - passCount;
    final rate = _items.isEmpty ? 0.0 : passCount / _items.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('IMU 데이터베이스', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorBox(message: _error!, onRetry: _fetch)
          : RefreshIndicator(
        onRefresh: _fetch,
        child: CustomScrollView(
          slivers: [
            // 상단 카드: 원형 게이지 + 범례
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, cons) {
                        // 도넛 지름 계산
                        final donutSize = cons.maxWidth.clamp(200.0, 250.0);

                        return SizedBox(
                          height: donutSize, // 카드 높이를 도넛 지름만큼 확보
                          child: Stack(
                            children: [
                              // 도넛 자체 (가운데 정렬)
                              Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: donutSize,
                                  height: donutSize,
                                  child: _Donut(
                                    rate: rate,
                                    total: _items.length,
                                    fixedSize: donutSize,
                                    thicknessRatio: 0.20,
                                  ),
                                ),
                              ),

                              // 범례: 오른쪽 아래에 배치
                              Positioned(
                                right: 1,
                                bottom: 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _LegendDot(color: Colors.green, label: '합격 ($passCount)'),
                                    const SizedBox(height: 6),
                                    _LegendDot(color: Colors.red, label: '불합격 ($failCount)'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),


            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // 리스트
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFE9ECEF)),
              itemBuilder: (ctx, i) {
                final item = _items[i];
                final color = item.passed ? Colors.green : Colors.red;
                final statusText = item.passed ? '합격' : '불합격';

                return InkWell(
                  onTap: () {
                    // 상세 라우트는 다음 단계에서 구현: '/imu/detail'
                    Navigator.pushNamed(context, '/imu/detail', arguments: item);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                    child: Row(
                      children: [
                        // 좌측 상태 점
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),

                        // 시리얼
                        Expanded(
                          child: Text(
                            item.code,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),

                        // 우측: 합격/불합격 + >
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: item.passed ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 13)),
          ],
        ),
      ),
    );

  }
}

/// --- 모델 / 뷰모델 ---

class ImuRecord {
  final String code; //001
  final String? serial;
  final DateTime inspectedAt;
  final bool passed;
  final String? inspectorName;
  final int? boxNo;
  final String? destination;
  final bool arrived;
  final double? roll, pitch, yaw;

  ImuRecord({
    required this.code,
    this.serial,
    required this.inspectedAt,
    required this.passed,
    this.inspectorName,
    this.boxNo,
    this.destination,
    required this.arrived,
    this.roll, this.pitch, this.yaw,
  });

  factory ImuRecord.fromJson(Map<String, dynamic> m) {
    // code가 없으면(구버전 서버/데이터) id를 3자리로 패딩해 백업
    final fallbackCode = (m['id'] != null) ? m['id'].toString().padLeft(3, '0') : '---';

    return ImuRecord(
      code: (m['code'] as String?) ?? fallbackCode,
      serial: m['serial'] as String?,
      inspectedAt: DateTime.parse(m['inspected_at'] as String),
      passed: m['passed'] as bool,
      inspectorName: m['inspector_name'] as String?,
      boxNo: (m['box_no'] as num?)?.toInt(),        // ✅ null-safe
      destination: m['destination'] as String?,
      arrived: (m['arrived'] as bool?) ?? false,    // ✅ null-safe
      roll: (m['roll'] as num?)?.toDouble(),        // ✅ null-safe
      pitch: (m['pitch'] as num?)?.toDouble(),      // ✅ null-safe
      yaw: (m['yaw'] as num?)?.toDouble(),          // ✅ null-safe
    );
  }
}


/// --- 위젯 파편 ---

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
class _Donut extends StatelessWidget {
  const _Donut({
    super.key,
    required this.rate,
    required this.total,
    this.fixedSize,              // 외부에서 강제 지름을 줄 때 사용
    this.thicknessRatio = 0.10,  // 지름 대비 두께 (얇게: 0.08~0.12)
  });

  final double rate; // 0.0 ~ 1.0
  final int total;
  final double? fixedSize;
  final double thicknessRatio;

  @override
  Widget build(BuildContext context) {
    final pct = (rate.clamp(0, 1) * 100).round();
    final screenW = MediaQuery.of(context).size.width;
    final size = (fixedSize ?? (math.min(screenW, 420) * 0.64)).clamp(160.0, 360.0);
    final stroke = (size * thicknessRatio).clamp(6.0, 14.0);

    // 텍스트가 링 안에 확실히 들어오도록 비율로 계산
    final pctFont = size * 0.18;   // 퍼센트
    final subFont = size * 0.075;  // '총 n개'
    final gap = size * 0.02;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 도넛 자체를 직접 그림
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              progress: rate.clamp(0.0, 1.0),
              stroke: stroke,
              bgColor: const Color(0xFFE9ECEF),
              fgColor: const Color(0xFF2ECC71),
            ),
          ),
          // 중앙 텍스트 - 항상 정확히 중앙
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pct %',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: pctFont,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: gap),
                Text(
                  '총 $total개',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: subFont,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.stroke,
    required this.bgColor,
    required this.fgColor,
  });

  final double progress; // 0~1
  final double stroke;
  final Color bgColor;
  final Color fgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // 시작각을 -90도로 해서 위쪽에서 시작(시각적 기대치와 일치)
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    // 배경 링
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2 * math.pi, false, bgPaint,
    );

    // 진행 링
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, false, fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.progress != progress || old.stroke != stroke
        || old.bgColor != bgColor || old.fgColor != fgColor;
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('데이터 로딩 실패', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

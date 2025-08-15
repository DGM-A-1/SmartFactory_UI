import 'dart:convert';
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Donut(rate: rate, total: _items.length),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendDot(color: Colors.green, label: '합격 ($passCount)'),
                            const SizedBox(height: 8),
                            _LegendDot(color: Colors.red, label: '불합격 ($failCount)'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 리스트 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'IMU 시리얼 넘버',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                      ),
                      Text(
                        '합격여부 / 세부사항',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
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
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
  const _Donut({required this.rate, required this.total});
  final double rate; // 0.0 ~ 1.0
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).round();
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 바탕 트랙
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 14,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFE9ECEF)),
          ),
          // 합격률
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: rate.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            builder: (context, v, _) {
              return CircularProgressIndicator(
                value: v,
                strokeWidth: 14,
                valueColor: const AlwaysStoppedAnimation(Colors.green),
                backgroundColor: Colors.transparent,
              );
            },
          ),
          // 가운데 텍스트
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$pct %', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('총 $total개', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
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

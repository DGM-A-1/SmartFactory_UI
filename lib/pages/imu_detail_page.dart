import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ ImuRecord는 imu_db_page.dart 안에 있으므로 그 파일에서 타입만 가져온다.
// 경로는 프로젝트 구조에 맞게 조정 (여기선 pages 폴더 기준)
import 'package:smartfactory_ui/pages/imu_db_page.dart' show ImuRecord;

class ImuDetailPage extends StatelessWidget {
  const ImuDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! ImuRecord) {
      return _errorScaffold('잘못된 접근입니다.');
    }
    final item = args;

    String d(Object? v) => (v == null || (v is String && v.trim().isEmpty)) ? '-' : '$v';
    String dYN(bool b) => b ? 'Y' : 'N';
    String? dAngle(num? v) => (v == null) ? null : '${v.toStringAsFixed(0)} °';
    final dtFmt = DateFormat('yyyy/MM/dd HH:mm:ss');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('세부사항', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              _FieldBox(title: 'IMU 모델명', value: d('MPU 9250')), // 서버에서 제공되면 교체
              _FieldBox(title: 'IMU 시리얼 넘버', value: d(item.code)),
              _FieldBox(title: '진단시간', value: dtFmt.format(item.inspectedAt.toLocal())),
              const Divider(thickness: 2, height: 25,),
              _FieldBox(title: '박스번호', value: d(item.boxNo)),
              _FieldBox(title: '목적지', value: d(item.destination)),
              _FieldBox(title: '도착 여부', value: dYN(item.arrived)),
              const Divider(thickness: 2, height: 25,),
              _FieldBox(title: 'Roll', value: d(dAngle(item.roll))),
              _FieldBox(title: 'Pitch', value: d(dAngle(item.pitch))),
              _FieldBox(title: 'Yaw', value: d(dAngle(item.yaw))),
            ],
          ),
        ),
      ),
    );
  }

  Scaffold _errorScaffold(String msg) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('세부사항'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Center(child: Text(msg)),
    );
  }
}

/// 한 줄짜리 “텍스트 박스” (왼쪽: 항목 / 오른쪽: 값)
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.title, required this.value, this.margin = const EdgeInsets.only(bottom: 10)});

  final String title;
  final String value;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

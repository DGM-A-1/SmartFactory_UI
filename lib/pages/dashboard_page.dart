import 'package:flutter/material.dart';
import 'package:smartfactory_ui/core/auth.dart';
import 'package:smartfactory_ui/widgets/sf_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const double _kButtonWidthFactor = 0.86;
  static const double _kButtonHeight = 56;
  static const Color _kActionYellow = Color(0xFFFFD233);
  static const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final user = auth.value.user;
    final display = (user?.name != null && user!.name!.trim().isNotEmpty)
        ? user.name!
        : (user?.email ?? '사용자');

    return SFPage(
      title: '메인',
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 인사 문구
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$display님, 반갑습니다!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Colors.black, // ✅ 검정색
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '원하시는 메뉴를\n선택해주세요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: Colors.black, // ✅ 검정색
                    ),
                  ),
                ],
              ),

              // 위쪽 공간: 작게
              const Spacer(flex: 2),

              // 버튼 묶음 (가운데 정렬)
              Align(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FractionallySizedBox(
                      widthFactor: _kButtonWidthFactor,
                      child: SizedBox(
                        height: _kButtonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kActionYellow,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: const RoundedRectangleBorder(
                                borderRadius: _kRadius),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/imu-test'),
                          child: const Text('IMU 데이터베이스 확인'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // 버튼 간 간격
                    FractionallySizedBox(
                      widthFactor: _kButtonWidthFactor,
                      child: SizedBox(
                        height: _kButtonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kActionYellow,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: const RoundedRectangleBorder(
                                borderRadius: _kRadius),
                            elevation: 0,
                          ),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/robot-call'),
                          child: const Text('로봇 호출'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 아래쪽 공간: 크게 (→ 버튼을 조금 위로 밀어올림)
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

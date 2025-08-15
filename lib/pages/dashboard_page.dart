import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../widgets/sf_page.dart';
import '../core/auth.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const double _buttonWidthFactor = 0.86;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState>(
      valueListenable: auth,
      builder: (context, state, _) {
        final nameOrEmail = state.user?.name?.trim().isNotEmpty == true
            ? state.user!.name!
            : (state.user?.email ?? '사용자');

        return SFPage(
          title: '메인',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const SizedBox(height: 8),
              // 환영 문구
              Text(
                '$nameOrEmail님! 반갑습니다.',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),

              // 로봇 호출하기 (Primary)
              FractionallySizedBox(
                widthFactor: _buttonWidthFactor,
                child: SizedBox(
                  height: 56,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      Navigator.pushNamed(context, '/robot-call');
                    },
                    padding: EdgeInsets.zero,
                    child: const Text('로봇 호출하기'),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // IMU 시험 테스트 확인 (Secondary)
              FractionallySizedBox(
                widthFactor: _buttonWidthFactor,
                child: SizedBox(
                  height: 56,
                  child: CupertinoButton(
                    color: Colors.white,
                    onPressed: () {
                      Navigator.pushNamed(context, '/imu-test');
                    },
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'IMU 시험 테스트 확인',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

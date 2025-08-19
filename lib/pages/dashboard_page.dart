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
                children: const [
                  _WelcomeTitle(),
                  SizedBox(height: 8),
                  Text(
                    '원하시는 메뉴를\n선택해주세요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              // 위쪽 공간: 작게
              const Spacer(flex: 2),

              // 가운데 버튼 묶음
              Align(
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // IMU 버튼
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
                              borderRadius: _kRadius,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/imu-test'),
                          child: const Text('IMU 데이터베이스 확인'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 로봇 호출 버튼
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
                              borderRadius: _kRadius,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/robot-call'),
                          child: const Text('로봇 호출'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // ── 구분선 + 퀵 링크(홈/설정/알림 …) ─────────────────────────────
              const Divider(height: 32, thickness: 1),
              _FooterQuickLinks(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle();

  @override
  Widget build(BuildContext context) {
    final user = auth.value.user;
    final display = (user?.name != null && user!.name!.trim().isNotEmpty)
        ? user.name!
        : (user?.email ?? '사용자');

    return Text(
      '$display님, 반갑습니다!',
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: Colors.black,
      ),
    );
  }
}

class _FooterQuickLinks extends StatelessWidget {
  const _FooterQuickLinks();

  static const TextStyle _linkStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              // 홈으로: 초기화면으로 이동 (필요 시 라우트명 수정)
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
            child: const Text('홈으로', style: _linkStyle),
          ),
          _dot(),
          TextButton(
            onPressed: () {
              // 설정 페이지 (라우트명 프로젝트에 맞춰 조정)
              Navigator.pushNamed(context, '/settings');
            },
            child: const Text('설정', style: _linkStyle),
          ),
          _dot(),
          TextButton(
            onPressed: () {
              // 알림 페이지 (라우트명 프로젝트에 맞춰 조정)
              Navigator.pushNamed(context, '/notifications');
            },
            child: const Text('알림', style: _linkStyle),
          ),
          // 필요하면 더 추가: 도움말/로그아웃 등
          // _dot(),
          // TextButton(
          //   onPressed: () => Navigator.pushNamed(context, '/help'),
          //   child: const Text('도움말', style: _linkStyle),
          // ),
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 2),
    child: Text('·', style: TextStyle(fontSize: 14, color: Colors.black54)),
  );
}

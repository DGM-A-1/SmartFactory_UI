import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth.dart'; // ✅ 로그인 상태 읽기 (ValueNotifier<AuthState> auth)

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  // 디자인 토큰
  static const Color kLime = Color(0xFFB9FF73);
  static const double kButtonWidthFactor = 0.86; // 버튼 가로폭(화면의 86%)

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kLime, // 전체 배경 연두
      body: SafeArea(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          // 연두색 배경이라 상태바 아이콘은 어두운 색이 보기 좋아요
          value: SystemUiOverlayStyle.dark,
          child: Column(
            children: [
              // 로고: 더 크게 + 위로 배치
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.25),
                  child: Image.asset(
                    'assets/images/mainlogo.png',
                    width: (size.width * 0.75).clamp(0, 380).toDouble(),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),

              // 하단 버튼들: 가로폭 좁게
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    // ✅ 첫 번째 버튼만 로그인 상태에 따라 라벨/경로 교체
                    ValueListenableBuilder<AuthState>(
                      valueListenable: auth,
                      builder: (context, state, _) {
                        final isLoggedIn = state.isLoggedIn;
                        final label = isLoggedIn ? '메인' : '로그인';
                        final route = isLoggedIn ? '/dashboard' : '/login';
                        return FractionallySizedBox(
                          widthFactor: kButtonWidthFactor,
                          child: _PrimaryBannerButton(
                            label: label,
                            routeName: route,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 두 번째 버튼(관리자 등록)은 그대로 유지
                    FractionallySizedBox(
                      widthFactor: kButtonWidthFactor,
                      child: const _SecondaryBannerButton(
                        label: '관리자 등록',
                        routeName: '/admin-register',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 재사용 가능한 배너 버튼
class _PrimaryBannerButton extends StatelessWidget {
  const _PrimaryBannerButton({required this.label, required this.routeName});
  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.pushNamed(context, routeName),
        child: Text(label),
      ),
    );
  }
}

class _SecondaryBannerButton extends StatelessWidget {
  const _SecondaryBannerButton({required this.label, required this.routeName});
  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue, width: 1.5),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => Navigator.pushNamed(context, routeName),
        child: Text(label),
      ),
    );
  }
}

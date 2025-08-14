import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                  // y가 -1.0(맨 위) ~ 1.0(맨 아래). -0.25면 살짝 위로
                  alignment: const Alignment(0, -0.65),
                  child: Image.asset(
                    'assets/images/mainlogo.png', // 투명 배경 PNG 권장
                    // 화면 폭의 75%, 최대 380px
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
                    FractionallySizedBox(
                      widthFactor: kButtonWidthFactor,
                      child: const _PrimaryBannerButton(
                        label: '로그인',
                        routeName: '/login',
                      ),
                    ),
                    const SizedBox(height: 12),
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

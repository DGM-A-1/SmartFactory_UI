// lib/widgets/sf_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import '../core/auth.dart';

class SFPage extends StatelessWidget {
  const SFPage({
    super.key,
    required this.title,
    required this.child,
    this.background = Colors.white,
    this.onTapMenu,
    this.onTapProfile,
    this.menuWidthFactor = 0.70, // 화면의 70%
    // ▼ 새 멤버 콜백(옵션)
    this.onImuDb,
    this.onRobotCall,
  });

  final String title;
  final Widget child;
  final Color background;
  final VoidCallback? onTapMenu;
  final VoidCallback? onTapProfile;
  final double menuWidthFactor;

  // ▼ 새 멤버 콜백
  final VoidCallback? onImuDb;
  final VoidCallback? onRobotCall;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: background,
        border: null,
        middle: Text(
          title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTapMenu ?? () => _showLeftSideSheet(context),
          child: const Icon(CupertinoIcons.line_horizontal_3, color: Colors.black),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTapProfile ?? () => Navigator.of(context).pushNamed('/my'),
          child: const Icon(CupertinoIcons.person_crop_circle, color: Colors.black),
        ),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }

  void _showLeftSideSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'menu',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.20),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final slide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(
          position: slide,
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: menuWidthFactor,
                heightFactor: 1,
                child: ValueListenableBuilder<AuthState>(
                  valueListenable: auth,
                  builder: (context, state, _) {
                    return _MenuPanel(
                      state: state,
                      // 공통 항목
                      onGoHome: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                      },
                      onSettings: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed('/settings');
                      },
                      onNotifications: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed('/notifications');
                      },
                      onHelp: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushNamed('/help');
                      },
                      onLogout: () async {
                        Navigator.pop(ctx);
                        try {
                          await AuthService.logout();
                        } catch (_) {}
                        Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      // 새 항목
                      onImuDb: onImuDb ??
                              () {
                            Navigator.pop(ctx);
                            // NOTE: 프로젝트에서 쓰는 라우트명으로 맞춰주세요.
                            // 대시보드 코드 기준: '/imu-test'
                            Navigator.of(context).pushNamed('/imu-test');
                          },
                      onRobotCall: onRobotCall ??
                              () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamed('/robot-call');
                          },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.state,
    required this.onGoHome,
    required this.onSettings,
    required this.onNotifications,
    required this.onHelp,
    required this.onLogout,
    // 새 항목
    required this.onImuDb,
    required this.onRobotCall,
  });

  final AuthState state;

  // 공통
  final VoidCallback onGoHome;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  // 새 항목
  final VoidCallback onImuDb;
  final VoidCallback onRobotCall;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoTheme.of(context),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              // 제목
              const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // ▽ 상단 회색 정보 블록 (상태에 따라 내용만 교체)
              if (!state.isLoggedIn) ...[
                const Text(
                  '로그인이 필요합니다',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                Text(
                  '이름: ${state.user?.name ?? state.user?.email ?? '-'}',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '부서: ${state.user?.department ?? '-'}',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '직책: ${state.user?.position ?? '-'}',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),

              // ▽ 공통 메뉴 (로그인 여부와 무관하게 항상 노출)
              _Item('IMU 데이터베이스 확인', onImuDb),
              _Item('로봇 호출', onRobotCall),
              const SizedBox(height: 8),
              const Divider(height: 1),
              _Item('홈으로', onGoHome),
              _Item('설정', onSettings),
              _Item('알림', onNotifications),
              _Item('도움말', onHelp),
              const SizedBox(height: 8),
              const Divider(height: 1),
              _Item('로그아웃', onLogout, destructive: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.label, this.onTap, {this.destructive = false});
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = destructive ? CupertinoColors.systemRed : Colors.black;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}

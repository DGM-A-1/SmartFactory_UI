import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Checkbox, CheckboxThemeData, Material, VisualDensity, MaterialTapTargetSize, CheckboxTheme;
import 'package:smartfactory_ui/widgets/sf_page.dart';

import '../core/auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _autoLogin = false;
  bool _obscure = true;

  // ✅ 활성화 조건: 이메일 또는 비밀번호 중 "하나라도" 입력되면 true
  bool get _canAttemptLogin =>
      _emailCtrl.text.trim().isNotEmpty && _pwCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }
  void _onLogin() async {
    try {
      await AuthService.login(_emailCtrl.text.trim(), _pwCtrl.text.trim());
      if (mounted) Navigator.pop(context); // 로그인 성공 후 닫기/이동 (원하는대로 변경)
    } catch (e) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('로그인 실패'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(child: const Text('확인'), onPressed: () => Navigator.pop(context)),
          ],
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '로그인',
      child : ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const SizedBox(height: 6),
            const Text(
              '이메일을\n입력해주세요',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),

            // 이메일
            CupertinoTextField(
              controller: _emailCtrl,
              placeholder: '이메일 입력',
              placeholderStyle:
              const TextStyle(color: CupertinoColors.systemGrey),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              clearButtonMode: OverlayVisibilityMode.editing,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              style: const TextStyle(color: Colors.black),
              decoration: _fieldDecoration(context),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // 비밀번호
            CupertinoTextField(
              controller: _pwCtrl,
              placeholder: '비밀번호 입력',
              placeholderStyle:
              const TextStyle(color: CupertinoColors.systemGrey),
              obscureText: _obscure,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              style: const TextStyle(color: Colors.black),
              decoration: _fieldDecoration(context),
              onChanged: (_) => setState(() {}),
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                minSize: 0,
                onPressed: () => setState(() => _obscure = !_obscure),
                child: Icon(
                  _obscure ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 20,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 로그인 버튼: _canAttemptLogin 기준으로 활성/비활성
            SizedBox(
              height: 48,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(10),
                onPressed: _canAttemptLogin ? _onLogin : null,
                child: const Text('로그인'),
              ),
            ),
            const SizedBox(height: 14),

            // ===== 하단 옵션 영역 정렬: 좌/중/우 =====
            // Row + Expanded 3칸으로 배치 → 오버플로우 방지
            Material(
              color: Colors.transparent, // Checkbox를 위해 Material 컨텍스트 제공
              child: CheckboxTheme(
                data: const CheckboxThemeData(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    // 왼쪽: 자동 로그인(체크박스 + 라벨)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _autoLogin,
                            onChanged: (v) => setState(() => _autoLogin = v ?? false),
                            activeColor: CupertinoColors.activeBlue,
                          ),
                          const SizedBox(width: 4),
                          const Flexible(
                            child: Text('자동 로그인',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.black)),
                          ),
                        ],
                      ),
                    ),
                    // 가운데: 이메일 찾기(중앙 정렬)
                    const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: _LinkButton(
                          label: '이메일 찾기',
                          onPressed: () {}, // TODO: 화면 연결
                        ),
                      ),
                    ),
                    // 오른쪽: 비밀번호 찾기(우측 정렬)
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _LinkButton(
                          label: '비밀번호 찾기',
                          onPressed: () {}, // TODO: 화면 연결
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }



  BoxDecoration _fieldDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: CupertinoColors.systemGrey4, width: 1),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 0,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: CupertinoColors.activeBlue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

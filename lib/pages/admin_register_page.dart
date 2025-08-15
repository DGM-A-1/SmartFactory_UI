import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../widgets/sf_page.dart';
import '../core/auth.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({super.key});

  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _dept = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController(); // 현재 API엔 안 보냄(필요 시 확장)

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _dept.dispose();
    _position.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '관리자 등록',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const SizedBox(height: 4),
          // 로고(작게, 중앙)
          Center(
            child: Image.asset(
              'assets/images/mainlogo.png',
              width: 56, // 시안 크기 느낌
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),

          const Center(
            child: Text(
              'Welcome to Fiveguys!',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),

          _field(label: '이름', controller: _name),
          const SizedBox(height: 10),
          _field(
            label: '이메일',
            controller: _email,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _field(
            label: '비밀번호',
            controller: _password,
            obscure: true,
          ),
          const SizedBox(height: 10),
          _field(label: '부서', controller: _dept),
          const SizedBox(height: 10),
          _field(label: '직책', controller: _position),
          const SizedBox(height: 10),
          _field(
            label: '연락처',
            controller: _phone,
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 22),

          SizedBox(
            height: 48,
            child: CupertinoButton.filled(
              onPressed: _busy ? null : _onSubmit,
              padding: EdgeInsets.zero,
              child: _busy
                  ? const CupertinoActivityIndicator()
                  : const Text('가입 신청'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 라벨(검정, 작게)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        CupertinoTextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          placeholder: label,
          placeholderStyle: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 15,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CupertinoColors.systemGrey4, width: 1),
          ),
        ),
      ],
    );
  }

  Future<void> _onSubmit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      await showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('입력 확인'),
          content: Text('이메일과 비밀번호는 필수 항목입니다.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.register(
        email: email,
        password: password,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        departmentName: _dept.text.trim().isEmpty ? null : _dept.text.trim(),
        positionName: _position.text.trim().isEmpty ? null : _position.text.trim(),
        role: 'ADMIN',
      );

      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (_) => const CupertinoAlertDialog(
          title: Text('등록 완료'),
          content: Text('관리자 계정이 생성되었습니다.'),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context); // 이전 화면으로
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('등록 실패'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

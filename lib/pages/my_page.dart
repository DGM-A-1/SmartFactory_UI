import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smartfactory_ui/core/auth.dart'; // auth / AuthService / baseUrl 등을 가져오기 위함 (요약값 사용)

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}
// 파일 최상위(클래스 바깥)에 추가
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    super.key,
    required this.label,
    required this.child,
    this.dimLabel = false,
  });

  final String label;
  final Widget child;
  final bool dimLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7), // 박스 배경
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dimLabel ? Colors.black38 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
class _MyPageState extends State<MyPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // 클래스 필드에 추가
  final _nameFn = FocusNode();
  final _positionFn = FocusNode();
  final _deptFn = FocusNode();
  final _phoneFn = FocusNode();

  bool _editing = false;
  bool _dirty = false;

  TextStyle _valueStyle(bool enabled) {
    if (!_editing) {
      // 보기 모드
      return const TextStyle(
          fontWeight: FontWeight.w600, color: Colors.black87);
    }
    return TextStyle(
      fontWeight: FontWeight.w500,
      color: enabled ? Colors.black87 : Colors.black38,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _positionCtrl.dispose();
    _deptCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFn.dispose();
    _positionFn.dispose();
    _deptFn.dispose();
    _phoneFn.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_positionCtrl, _phoneCtrl]) {
      c.addListener(() {
        if (!_editing) return;
        setState(() => _dirty = true);
      });
    }
    _loadSummary();
  }
  Future<void> _apply() async {
    final tok = auth.value.token;
    if (tok == null || tok.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다.")),
      );
      return;
    }
    final uri = Uri.parse('${AuthService.baseUrl}/me/profile');

    // 빈 문자열은 null로 보내 => 서버에서 "해당 값 제거" 로직 처리 가능
    final body = {
      "position_name": _positionCtrl.text
          .trim()
          .isEmpty ? null : _positionCtrl.text.trim(),
      "phone": _phoneCtrl.text
          .trim()
          .isEmpty ? null : _phoneCtrl.text.trim(),
    };


    try {
      final res = await http
          .patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Auth-Token': tok,
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        // 서버가 Summary를 돌려준다고 가정 → 최신값으로 컨트롤러 갱신
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = (m['name'] ?? '').toString();
          _emailCtrl.text = (m['email'] ?? '').toString(); // 읽기전용
          _positionCtrl.text = (m['position'] ?? '').toString();
          _deptCtrl.text = (m['department'] ?? '').toString();
          _phoneCtrl.text = (m['phone'] ?? '').toString();
          _editing = false;
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 정보를 저장했습니다.')),
        );
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('세션이 만료되었어요. 다시 로그인해주세요.')),
        );
      } else if (res.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자를 찾을 수 없습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패 (${res.statusCode})')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류로 저장에 실패했습니다.')),
      );
    }
  }

  Future<void> _loadSummary() async {
    final tok = auth.value.token;
    if (tok == null || tok.isEmpty) return;
    final baseUrl = AuthService.baseUrl;
    final uri = Uri.parse(baseUrl).resolve('/me/summary');
    try {
      final res = await http
          .get(uri, headers: {'X-Auth-Token': tok})
          .timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _nameCtrl.text = (m['name'] ?? '').toString();
          _emailCtrl.text = (m['email'] ?? '').toString();
          _positionCtrl.text = (m['position'] ?? '').toString();
          _deptCtrl.text = (m['department'] ?? '').toString();
          _phoneCtrl.text = (m['phone'] ?? '').toString();
        });
      } else if (res.statusCode == 401) {
        // 토큰 만료 등: 선택적으로 로그아웃 처리
        // await AuthService.logout();
      }
    } catch (_) {
      // 필요 시 스낵바/로그
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      // ✅ Stack/Positioned.fill 대신 ListView로 단순/안정 레이아웃
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1) 초록 배너
          Container(
            height: 176,
            width: double.infinity,
            color: const Color(0xFF51A86E),
          ),

          // 2) 아바타 + 패널 (아바타가 위에 오도록 Stack)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 패널 (라운드 탑) : 내용은 여기 Column에 그대로
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 72, 16, 24), // 아바타 공간
                child: Column(
                  children: [
                    Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '이름',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _InfoPill(
                      label: '이름', dimLabel: _editing,
                      child: _pillValueField(_nameCtrl, enabled: false),
                    ),
                    const SizedBox(height: 12),

                    _InfoPill(
                      label: '이메일', dimLabel: _editing,
                      child: _pillValueField(
                        _emailCtrl, enabled: false,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _InfoPill(
                      label: '직책', dimLabel: _editing && !_editing,
                      child: _pillValueField(_positionCtrl, enabled: _editing),
                    ),
                    const SizedBox(height: 12),

                    _InfoPill(
                      label: '부서', dimLabel: _editing,
                      child: _pillValueField(_deptCtrl, enabled: false),
                    ),
                    const SizedBox(height: 12),

                    _InfoPill(
                      label: '연락처', dimLabel: _editing && !_editing,
                      child: _pillValueField(
                        _phoneCtrl, enabled: _editing,
                        keyboardType: TextInputType.phone,
                        hint: '010-xxxx-xxxx',
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 120, height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent, width: 1.2),
                              foregroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() { _editing = true; _dirty = false; });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('편집 모드입니다. 변경 후 [적용]을 누르세요.')),
                              );
                            },
                            child: const Text('수정'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120, height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: (_editing && _dirty) ? _apply : null,
                            child: const Text('적용'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 아바타: Stack 마지막에 두어 항상 패널 위에 보이게
              Positioned(
                top: -52, // 살짝 위에서 내려오도록
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12, offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFFEDE7F6),
                      child: Icon(Icons.person_outline, size: 52, color: Colors.deepPurple.shade400),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _pillValueField(TextEditingController ctrl, {
    required bool enabled,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      // 탭/포커스 차단
      keyboardType: keyboardType,
      style: _valueStyle(enabled),
      // 값 스타일
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        border: InputBorder.none, // 내부선 없음
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
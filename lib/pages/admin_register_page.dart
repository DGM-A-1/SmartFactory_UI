// lib/pages/admin_register_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../widgets/sf_page.dart';

class AdminRegisterPage extends StatelessWidget {
  const AdminRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SFPage(
      title: '관리자 등록',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: const [
          SizedBox(height: 6),
          Text('관리자 정보를 입력해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black)),
          // TODO: 폼 명세 주면 채움
        ],
      ),
    );
  }
}

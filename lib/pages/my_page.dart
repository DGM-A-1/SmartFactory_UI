// lib/pages/my_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../widgets/sf_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const SFPage(
      title: '마이페이지',
      child: Center(child: Text('마이페이지 내용', style: TextStyle(color: Colors.black))),
    );
  }
}

// lib/pages/settings_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import '../widgets/sf_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const SFPage(
      title: '설정',
      child: Center(child: Text('설정 화면', style: TextStyle(color: Colors.black))),
    );
  }
}
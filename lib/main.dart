import 'package:flutter/material.dart';
import 'package:smartfactory_ui/pages/admin_register_page.dart';
import 'package:smartfactory_ui/pages/login_page.dart';
import 'package:smartfactory_ui/pages/my_page.dart';
import 'package:smartfactory_ui/pages/settings_page.dart';
import 'pages/mainpage.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartFactoryApp());
}

class SmartFactoryApp extends StatelessWidget {
  const SmartFactoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFactory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // 연두색 전체 배경
        scaffoldBackgroundColor: const Color(0xFFB9FF73),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MainPage(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/admin-register': (_) => const AdminRegisterPage(),
        '/my': (_) => const MyPage(),
        '/settings' : (_) => const SettingsPage(),
      },
    );
  }
}

// 임시 페이지(나중에 실제 구현으로 교체)
class _StubPage extends StatelessWidget {
  const _StubPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title 화면 구현 예정')),
    );
  }
}

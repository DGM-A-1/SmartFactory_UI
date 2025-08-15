import 'package:flutter/material.dart';
import 'package:smartfactory_ui/pages/admin_register_page.dart';
import 'package:smartfactory_ui/pages/dashboard_page.dart';
import 'package:smartfactory_ui/pages/login_page.dart';
import 'package:smartfactory_ui/pages/my_page.dart';
import 'package:smartfactory_ui/pages/settings_page.dart';
import 'package:smartfactory_ui/widgets/sf_page.dart';
import 'core/auth.dart';
import 'pages/mainpage.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.bootstrap();
  runApp(const SmartFactoryApp());
}

class SmartFactoryApp extends StatefulWidget {
  const SmartFactoryApp({super.key});

  @override
  State<SmartFactoryApp> createState() => _SmartFactoryAppState();
}

class _SmartFactoryAppState extends State<SmartFactoryApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthService.bootstrap();
    });
  }

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

      routes: {
        '/login': (_) => const LoginPage(),
        '/admin-register': (_) => const AdminRegisterPage(),
        '/my': (_) => const MyPage(),
        '/settings': (_) => const SettingsPage(),
        '/dashboard':(_) => const DashboardPage(),
        '/robot-call': (_) => const _StubPage(title: '로봇 호출하기'),
        '/imu-test': (_) => const _StubPage(title: 'IMU 시험 테스트 확인'),
        '/help':(_) => const _StubPage(title: "도움말 페이지"),
        '/notifications':(_) => const _StubPage(title: "알림 페이지"),
      },
      home: const MainPage(),
    );
  }
}

// 임시 페이지(나중에 실제 구현으로 교체)
class _StubPage extends StatelessWidget {
  const _StubPage({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SFPage(
        title: title,
        child: const Center(child: Text("화면 구현 예정"))
    );
  }
}

// lib/core/auth.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserSummary {
  final String? name;
  final String email;
  final String department;
  final String position;
  final String role;

  const UserSummary({
    this.name,
    required this.email,
    required this.department,
    required this.position,
    required this.role,
  });

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
    name: j['name'] as String?,
    email: (j['email'] ?? '-') as String,
    department: (j['department'] ?? '-') as String,
    position: (j['position'] ?? '-') as String,
    role: (j['role'] ?? 'USER') as String,
  );
}

class AuthState {
  final bool isLoggedIn;
  final String? token;
  final UserSummary? user;

  const AuthState({required this.isLoggedIn, this.token, this.user});

  factory AuthState.loggedOut() => const AuthState(isLoggedIn: false);

  AuthState copyWith({bool? isLoggedIn, String? token, UserSummary? user}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        token: token ?? this.token,
        user: user ?? this.user,
      );
}

final ValueNotifier<AuthState> auth =
ValueNotifier<AuthState>(AuthState.loggedOut());

class AuthService {
  // 플랫폼별 로컬 서버 기본값
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static const _storage = FlutterSecureStorage();
  static const _kTokenKey = 'sf_token_v1';

  /// 앱 시작 시 토큰 복원 + 요약 로드
  static Future<void> bootstrap() async {
    final tok = await _storage.read(key: _kTokenKey);
    if (tok == null) {
      auth.value = AuthState.loggedOut();
      return;
    }
    auth.value = auth.value.copyWith(isLoggedIn: true, token: tok);
    // 토큰 유효하면 요약 조회
    try {
      final me = await _getSummary(tok);
      auth.value = auth.value.copyWith(user: me);
    } catch (e) {
      debugPrint('bootstrap summary failed: $e');
      await logout(); // 토큰 무효 시 정리
    }
  }

  static Future<void> register({
    required String email,
    required String password,
    String? name,
    String? departmentName,
    String? positionName,
    String role = 'USER',
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'department_name': departmentName,
        'position_name': positionName,
        'role': role,
      }),
    );
    if (r.statusCode >= 300) {
      throw Exception('회원가입 실패: ${r.statusCode} ${r.body}');
    }
  }

  static Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode != 200) {
      throw Exception('로그인 실패: ${r.statusCode} ${r.body}');
    }
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final token = (m['token'] ?? m['access_token']) as String;
    await _storage.write(key: _kTokenKey, value: token);

    // 상태 업데이트
    auth.value = auth.value.copyWith(isLoggedIn: true, token: token);

    // 요약 로드
    UserSummary summary;
    if (m['summary'] != null) {
      summary = UserSummary.fromJson(m['summary'] as Map<String, dynamic>);
    } else {
      summary = await _getSummary(token);
    }
    auth.value = auth.value.copyWith(user: summary);
  }

  static Future<void> logout() async {
    final tok = auth.value.token;
    try {
      if (tok != null && tok.isNotEmpty) {
        final uri = Uri.parse(baseUrl).resolve('/auth/logout');
        await http
            .post(uri,headers:{'X-Auth-Token': tok})
            .timeout(const Duration(seconds: 5)
        );
      }
    } catch (_) {}
    await _storage.delete(key: _kTokenKey);
    auth.value = AuthState.loggedOut();
  }

  static Future<UserSummary> _getSummary(String token) async {
    final r = await http.get(
      Uri.parse('$baseUrl/me/summary'),
      headers: {'X-Auth-Token': token},
    );
    if (r.statusCode != 200) {
      throw Exception('요약 조회 실패: ${r.statusCode} ${r.body}');
    }
    return UserSummary.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}

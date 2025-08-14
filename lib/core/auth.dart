// lib/core/auth.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UserSummary {
  final String? name;
  final String email;
  final String department;
  final String position;
  const UserSummary({this.name,required this.email, required this.department, required this.position});

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
    name: j['name'] as String?,
    email: j['email'] ?? '-',
    department: j['department'] ?? '-',
    position: j['position'] ?? '-',
  );
}

class AuthState {
  final bool isLoggedIn;
  final String? accessToken;
  final UserSummary? user;
  const AuthState({required this.isLoggedIn, this.accessToken, this.user});

  factory AuthState.loggedOut() => const AuthState(isLoggedIn: false);

  AuthState copyWith({bool? isLoggedIn, String? accessToken, UserSummary? user}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        accessToken: accessToken ?? this.accessToken,
        user: user ?? this.user,
      );
}

/// 앱 전역에서 구독하는 인증 상태
final ValueNotifier<AuthState> auth = ValueNotifier<AuthState>(AuthState.loggedOut());

class AuthService {
  // TODO: 너의 백엔드 주소로 바꿔줘 (예: https://smartfactory-api.onrender.com)
  static const String baseUrl = 'https://<YOUR_BACKEND_DOMAIN>';

  /// 로그인 → 토큰 저장 → 사용자 요약 정보 로드
  static Future<void> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (r.statusCode != 200) {
      throw Exception('로그인 실패 (${r.statusCode})');
    }
    final token = (jsonDecode(r.body) as Map)['access_token'] as String;
    auth.value = auth.value.copyWith(isLoggedIn: true, accessToken: token);

    // 로그인 후 요약 정보 불러오기
    final m = await http.get(
      Uri.parse('$baseUrl/me/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (m.statusCode == 200) {
      auth.value = auth.value.copyWith(
        user: UserSummary.fromJson(jsonDecode(m.body) as Map<String, dynamic>),
      );
    }
  }

  static void logout() {
    auth.value = AuthState.loggedOut();
    // 필요하면 SecureStorage에 저장된 토큰도 같이 지우기
  }
}

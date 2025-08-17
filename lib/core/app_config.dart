import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();
  static final AppConfig I = AppConfig._();

  // 기본값은 지금 Jetson IP로
  final ValueNotifier<String> rosWsUrl =
  ValueNotifier<String>('ws://100.108.7.35:9090');

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    rosWsUrl.value = sp.getString('ros_ws_url') ?? rosWsUrl.value;
  }

  Future<void> saveRosUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('ros_ws_url', url);
    rosWsUrl.value = url;
  }
}

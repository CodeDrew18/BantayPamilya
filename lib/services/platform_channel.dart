import 'package:flutter/services.dart';

class AppBlockerChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.example.bantay_pamilya/app_blocker',
  );

  static Future<void> setBlockedPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod('setBlockedPackages', {'packages': packages});
    } catch (_) {}
  }

  static Future<void> requestUsageAccess() async {
    try {
      await _channel.invokeMethod('requestUsageAccess');
    } catch (_) {}
  }

  static Future<void> requestAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('requestAccessibilitySettings');
    } catch (_) {}
  }
}

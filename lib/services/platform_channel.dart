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

  static Future<void> requestMonitoringPermissions() async {
    try {
      await _channel.invokeMethod('requestMonitoringPermissions');
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getCallLogs({
    int limit = 50,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getCallLogs', {
        'limit': limit,
      });
      return (result ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> getSmsLogs({int limit = 50}) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getSmsLogs', {
        'limit': limit,
      });
      return (result ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> getContacts({
    int limit = 100,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getContacts', {
        'limit': limit,
      });
      return (result ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

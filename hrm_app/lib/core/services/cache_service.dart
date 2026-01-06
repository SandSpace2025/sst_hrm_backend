import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CacheService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const Duration _shortCacheDuration = Duration(minutes: 5);
  static const Duration _mediumCacheDuration = Duration(minutes: 15);
  static const Duration _longCacheDuration = Duration(hours: 1);

  static const String _dashboardKey = 'dashboard_data';
  static const String _profileKey = 'profile_data';
  static const String _employeesKey = 'employees_data';
  static const String _messagesKey = 'messages_data';
  static const String _announcementsKey = 'announcements_data';
  static const String _lastFetchKey = 'last_fetch_timestamp';

  static Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? customDuration,
  }) async {
    try {
      final cacheEntry = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry':
            (DateTime.now().millisecondsSinceEpoch +
            (customDuration ?? _mediumCacheDuration).inMilliseconds),
      };

      await _storage.write(key: key, value: json.encode(cacheEntry));
    } catch (e) {}
  }

  static Future<dynamic> getCachedData(String key) async {
    try {
      final cachedString = await _storage.read(key: key);
      if (cachedString == null) return null;

      final cacheEntry = json.decode(cachedString);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = cacheEntry['expiry'] as int;

      if (now > expiry) {
        await _storage.delete(key: key);
        return null;
      }

      return cacheEntry['data'];
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isDataStale(
    String key, {
    Duration? customDuration,
  }) async {
    try {
      final cachedString = await _storage.read(key: key);
      if (cachedString == null) return true;

      final cacheEntry = json.decode(cachedString);
      final now = DateTime.now().millisecondsSinceEpoch;
      final timestamp = cacheEntry['timestamp'] as int;
      final duration = customDuration ?? _mediumCacheDuration;

      return (now - timestamp) > duration.inMilliseconds;
    } catch (e) {
      return true;
    }
  }

  static Future<void> clearCache(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAllCache() async {
    await _storage.deleteAll();
  }

  static Future<void> cacheDashboardData(dynamic data, String userRole) async {
    final key = '${_dashboardKey}_$userRole';
    await cacheData(key, data, customDuration: _shortCacheDuration);
  }

  static Future<dynamic> getCachedDashboardData(String userRole) async {
    final key = '${_dashboardKey}_$userRole';
    return await getCachedData(key);
  }

  static Future<void> cacheProfileData(dynamic data, String userRole) async {
    final key = '${_profileKey}_$userRole';
    await cacheData(key, data, customDuration: _longCacheDuration);
  }

  static Future<dynamic> getCachedProfileData(String userRole) async {
    final key = '${_profileKey}_$userRole';
    return await getCachedData(key);
  }

  static Future<void> cacheEmployeesData(dynamic data, String userRole) async {
    final key = '${_employeesKey}_$userRole';
    await cacheData(key, data, customDuration: _mediumCacheDuration);
  }

  static Future<dynamic> getCachedEmployeesData(String userRole) async {
    final key = '${_employeesKey}_$userRole';
    return await getCachedData(key);
  }

  static Future<void> cacheMessagesData(dynamic data, String userRole) async {
    final key = '${_messagesKey}_$userRole';
    await cacheData(key, data, customDuration: _shortCacheDuration);
  }

  static Future<dynamic> getCachedMessagesData(String userRole) async {
    final key = '${_messagesKey}_$userRole';
    return await getCachedData(key);
  }

  static Future<void> cacheAnnouncementsData(
    dynamic data,
    String userRole,
  ) async {
    final key = '${_announcementsKey}_$userRole';
    await cacheData(key, data, customDuration: _mediumCacheDuration);
  }

  static Future<dynamic> getCachedAnnouncementsData(String userRole) async {
    final key = '${_announcementsKey}_$userRole';
    return await getCachedData(key);
  }

  static Future<void> setLastFetchTime(String dataType, String userRole) async {
    final key = '${_lastFetchKey}_${dataType}_$userRole';
    await _storage.write(
      key: key,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  static Future<DateTime?> getLastFetchTime(
    String dataType,
    String userRole,
  ) async {
    final key = '${_lastFetchKey}_${dataType}_$userRole';
    final timestamp = await _storage.read(key: key);
    if (timestamp == null) return null;

    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp));
    } catch (e) {
      return null;
    }
  }

  static Future<bool> needsRefresh(
    String dataType,
    String userRole, {
    Duration? customDuration,
  }) async {
    final lastFetch = await getLastFetchTime(dataType, userRole);
    if (lastFetch == null) return true;

    final duration = customDuration ?? _mediumCacheDuration;
    return DateTime.now().difference(lastFetch) > duration;
  }
}

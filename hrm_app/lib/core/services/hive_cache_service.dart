import 'package:hive/hive.dart';
import 'dart:convert';

class HiveCacheService {
  static const String _dashboardBox = 'dashboardCache';
  static const String _profileBox = 'profileCache';
  static const String _messagesBox = 'messageCache';
  static const String _messagingBox = 'chatCache';
  static const String _payrollBox = 'payrollCache';
  static const String _payslipBox = 'payslipCache';
  static const String _announcementBox = 'announcementCache';
  static const String _leaveBox = 'leaveCache';
  static const String _employeeBox = 'employee_cache_box';
  static const String _adminDashboardBox = 'admin_dashboard_cache';

  static const int _shortCacheDuration = 24 * 60 * 60 * 1000;
  static const int _mediumCacheDuration = 15 * 60 * 1000;
  static const int _longCacheDuration = 60 * 60 * 1000;
  static const int _monthlyCacheDuration = 30 * 24 * 60 * 60 * 1000;

  static Future<Box> _getBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }

  static Map<String, dynamic> _createCacheEntry(dynamic data) {
    return {'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch};
  }

  static bool _isCacheValid(Map<String, dynamic> entry, int maxAge) {
    final timestamp = entry['timestamp'] as int?;
    if (timestamp == null) return false;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age < maxAge;
  }

  static Future<void> cacheDashboard(
    String role,
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    try {
      final box = await _getBox(_dashboardBox);
      final key = userId != null
          ? 'dashboard_${role}_$userId'
          : 'dashboard_$role';
      await box.put(key, _createCacheEntry(data));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getCachedDashboard(
    String role, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_dashboardBox);
      final key = userId != null
          ? 'dashboard_${role}_$userId'
          : 'dashboard_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _shortCacheDuration)) {
        await box.delete(key);
        return null;
      }

      final data = entry['data'];
      if (data == null) return null;

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheProfile(
    String role,
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    try {
      final box = await _getBox(_profileBox);
      // CRITICAL: Include userId in cache key to prevent data leakage between users of same role
      final key = userId != null ? 'profile_${role}_$userId' : 'profile_$role';
      await box.put(key, _createCacheEntry(data));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getCachedProfile(
    String role, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_profileBox);
      // CRITICAL: Include userId in cache key to prevent data leakage between users of same role
      final key = userId != null ? 'profile_${role}_$userId' : 'profile_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _longCacheDuration)) {
        await box.delete(key);
        return null;
      }

      final data = entry['data'];
      if (data == null) return null;

      if (data is Map) {
        try {
          final jsonString = jsonEncode(data);
          final decoded = jsonDecode(jsonString);
          if (decoded is Map) {
            return _convertMapRecursive(decoded);
          }
        } catch (e) {
          return null;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic> _convertMapRecursive(dynamic map) {
    if (map is Map<String, dynamic>) {
      return map;
    }

    if (map is! Map) {
      throw Exception('Expected Map, got ${map.runtimeType}');
    }

    final result = <String, dynamic>{};

    try {
      final entries = map.entries.toList();
      for (final entry in entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value == null) {
          result[key] = null;
        } else if (value is Map) {
          result[key] = _convertMapRecursive(value);
        } else if (value is List) {
          result[key] = value.map((item) {
            if (item is Map) {
              return _convertMapRecursive(item);
            }
            return item;
          }).toList();
        } else {
          result[key] = value;
        }
      }
    } catch (e) {
      try {
        final temp = Map.from(map);
        return Map<String, dynamic>.fromEntries(
          temp.entries.map((e) => MapEntry(e.key.toString(), e.value)),
        );
      } catch (e2) {
        rethrow;
      }
    }

    return result;
  }

  static Future<void> cacheMessages(String role, List<dynamic> messages) async {
    try {
      final box = await _getBox(_messagesBox);
      final key = 'messages_$role';
      await box.put(key, _createCacheEntry(messages));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedMessages(
    String role, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_messagesBox);
      final key = 'messages_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _shortCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return List<dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheConversations(
    String role,
    List<dynamic> conversations,
  ) async {
    try {
      final box = await _getBox(_messagingBox);
      final key = 'conversations_$role';
      await box.put(key, _createCacheEntry(conversations));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedConversations(
    String role, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_messagingBox);
      final key = 'conversations_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _shortCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return List<dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheConversationMessages(
    String conversationId,
    List<dynamic> messages,
  ) async {
    try {
      final box = await _getBox(_messagingBox);
      final key = 'messages_$conversationId';
      await box.put(key, _createCacheEntry(messages));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedConversationMessages(
    String conversationId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_messagingBox);
      final key = 'messages_$conversationId';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _shortCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return List<dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheUserProfile(
    String userId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final box = await _getBox(_profileBox);
      final key = 'user_profile_$userId';
      await box.put(key, _createCacheEntry(profileData));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getCachedUserProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_profileBox);
      final key = 'user_profile_$userId';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _longCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return Map<String, dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cachePayroll(
    String role,
    String employeeId,
    List<dynamic> payrollData,
  ) async {
    try {
      final box = await _getBox(_payrollBox);
      final key = 'payroll_${role}_$employeeId';
      await box.put(key, _createCacheEntry(payrollData));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedPayroll(
    String role,
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_payrollBox);
      final key = 'payroll_${role}_$employeeId';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _mediumCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return List<dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cachePayslips(
    String role,
    List<dynamic> payslips, {
    String? userId,
  }) async {
    try {
      final box = await _getBox(_payslipBox);
      final key = userId != null
          ? 'payslips_${role}_$userId'
          : 'payslips_$role';
      await box.put(key, _createCacheEntry(payslips));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedPayslips(
    String role, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_payslipBox);
      final key = userId != null
          ? 'payslips_${role}_$userId'
          : 'payslips_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);

      if (!_isCacheValid(entry, _monthlyCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return List<dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheCurrentSalary(
    String role,
    Map<String, dynamic> salaryData, {
    String? userId,
  }) async {
    try {
      final box = await _getBox(_payslipBox);
      final key = userId != null
          ? 'current_salary_${role}_$userId'
          : 'current_salary_$role';
      await box.put(key, _createCacheEntry(salaryData));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getCachedCurrentSalary(
    String role, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_payslipBox);
      final key = userId != null
          ? 'current_salary_${role}_$userId'
          : 'current_salary_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);

      if (!_isCacheValid(entry, _monthlyCacheDuration)) {
        await box.delete(key);
        return null;
      }

      return Map<String, dynamic>.from(entry['data']);
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheAnnouncements(
    String role,
    List<dynamic> announcements,
  ) async {
    try {
      final box = await _getBox(_announcementBox);
      final key = 'announcements_$role';
      await box.put(key, _createCacheEntry(announcements));
    } catch (e) {}
  }

  static Future<List<dynamic>?> getCachedAnnouncements(
    String role, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_announcementBox);
      final key = 'announcements_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _mediumCacheDuration)) {
        await box.delete(key);
        return null;
      }

      final data = entry['data'];
      if (data == null) return null;

      if (data is List) {
        return data.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return item;
        }).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheLeaveBalance(
    String role,
    Map<String, dynamic> balanceData, {
    String? userId,
  }) async {
    try {
      final box = await _getBox(_leaveBox);
      final key = userId != null
          ? 'leave_balance_${role}_$userId'
          : 'leave_balance_$role';
      await box.put(key, _createCacheEntry(balanceData));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getCachedLeaveBalance(
    String role, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(_leaveBox);
      final key = userId != null
          ? 'leave_balance_${role}_$userId'
          : 'leave_balance_$role';
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      if (!_isCacheValid(entry, _mediumCacheDuration)) {
        await box.delete(key);
        return null;
      }

      final data = entry['data'];
      if (data is Map) {
        return _convertMapRecursive(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> cacheData(
    String boxName,
    String key,
    dynamic data, {
    int maxAge = _mediumCacheDuration,
  }) async {
    try {
      final box = await _getBox(boxName);
      final entry = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'maxAge': maxAge,
      };
      await box.put(key, entry);
    } catch (e) {}
  }

  static Future<dynamic> getCachedData(
    String boxName,
    String key, {
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) return null;

      final box = await _getBox(boxName);
      final cached = box.get(key);

      if (cached == null) return null;

      final entry = Map<String, dynamic>.from(cached);
      final maxAge = entry['maxAge'] as int? ?? _mediumCacheDuration;

      if (!_isCacheValid(entry, maxAge)) {
        await box.delete(key);
        return null;
      }

      return entry['data'];
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearCacheForRole(String role, String dataType) async {
    try {
      String boxName;
      String keyPrefix;

      switch (dataType.toLowerCase()) {
        case 'dashboard':
          boxName = _dashboardBox;
          keyPrefix = 'dashboard_';
          break;
        case 'profile':
          boxName = _profileBox;
          keyPrefix = 'profile_';
          break;
        case 'messages':
          boxName = _messagesBox;
          keyPrefix = 'messages_';
          break;
        case 'conversations':
        case 'messaging':
          boxName = _messagingBox;
          keyPrefix = 'conversations_';
          break;
        case 'payroll':
          boxName = _payrollBox;
          keyPrefix = 'payroll_';
          break;
        case 'payslips':
        case 'payslip':
          boxName = _payslipBox;
          keyPrefix = 'payslips_';
          break;
        case 'announcements':
          boxName = _announcementBox;
          keyPrefix = 'announcements_';
          break;
        default:
          return;
      }

      final box = await _getBox(boxName);
      final key = '$keyPrefix$role';
      await box.delete(key);
    } catch (e) {}
  }

  static Future<void> clearAllCacheForRole(String role) async {
    final dataTypes = [
      'dashboard',
      'profile',
      'messages',
      'conversations',
      'payroll',
      'payslips',
      'announcements',
    ];

    for (final dataType in dataTypes) {
      try {
        await clearCacheForRole(role, dataType);
      } catch (e) {
        // Ignore error and continue to next type
      }
    }
  }

  static Future<void> clearAllCache() async {
    final boxNames = [
      _dashboardBox,
      _profileBox,
      _messagesBox,
      _messagingBox,
      _payrollBox,
      _payslipBox,
      _announcementBox,
      _leaveBox,
      _employeeBox,
      _adminDashboardBox,
    ];

    for (final boxName in boxNames) {
      try {
        Box box;
        if (!Hive.isBoxOpen(boxName)) {
          box = await Hive.openBox(boxName);
        } else {
          box = Hive.box(boxName);
        }
        await box.clear();
      } catch (e) {
        // Ignore specific box error and continue
      }
    }
  }

  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final stats = <String, dynamic>{};
      final boxNames = [
        _dashboardBox,
        _profileBox,
        _messagesBox,
        _messagingBox,
        _payrollBox,
        _payslipBox,
        _announcementBox,
        _leaveBox,
      ];

      for (final boxName in boxNames) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          stats[boxName] = box.length;
        } else {
          stats[boxName] = 0;
        }
      }

      return stats;
    } catch (e) {
      return {};
    }
  }
}

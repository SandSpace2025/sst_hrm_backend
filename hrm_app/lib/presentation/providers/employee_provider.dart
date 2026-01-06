import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/data/repositories/employee_repository.dart';
import 'package:hrm_app/data/repositories/leave_repository.dart';
import 'package:hrm_app/data/repositories/messaging_repository.dart';
import 'package:hrm_app/data/repositories/payroll_repository.dart';
import 'package:hrm_app/data/repositories/announcement_repository.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:hrm_app/core/services/optimized_api_service.dart';
part 'employee_provider_dashboard.dart';
part 'employee_provider_leaves.dart';
part 'employee_provider_payroll.dart';
part 'employee_provider_messaging.dart';
part 'employee_provider_announcements.dart';
part 'employee_provider_eod.dart';
part 'employee_provider_notifications.dart';

class EmployeeProvider with ChangeNotifier {
  void _notify() => notifyListeners();
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  final LeaveRepository _leaveRepository = LeaveRepository();
  final MessagingRepository _messagingRepository = MessagingRepository();
  final PayrollRepository _payrollRepository = PayrollRepository();
  final AnnouncementRepository _announcementRepository =
      AnnouncementRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  String? get token => _token;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  Employee? _employeeProfile;
  Employee? get employeeProfile => _employeeProfile;

  List<dynamic> _eodEntries = [];
  List<dynamic> get eodEntries => _eodEntries;

  List<dynamic> _leaveRequests = [];
  List<dynamic> get leaveRequests => _leaveRequests;

  Map<String, dynamic>? _leaveBalance;
  Map<String, dynamic>? get leaveBalance => _leaveBalance;

  Map<String, dynamic>? _leaveStatistics;
  Map<String, dynamic>? get leaveStatistics => _leaveStatistics;

  List<dynamic> _blackoutDates = [];
  List<dynamic> get blackoutDates => _blackoutDates;

  Map<String, dynamic>? _messagingPermissions;
  Map<String, dynamic>? get messagingPermissions => _messagingPermissions;

  List<dynamic> _payslips = [];
  List<dynamic> get payslips => _payslips;

  Map<String, dynamic>? _currentSalary;
  Map<String, dynamic>? get currentSalary => _currentSalary;

  Map<String, dynamic>? _salaryBreakdown;
  Map<String, dynamic>? get salaryBreakdown => _salaryBreakdown;

  List<dynamic> _messages = [];
  List<dynamic> get messages => _messages;

  final Set<String> _unreadConversations = {};

  bool _messagesLoadedFromCache = false;

  List<dynamic> _hrContacts = [];
  List<dynamic> get hrContacts => _hrContacts;

  List<dynamic> _adminContacts = [];
  List<dynamic> get adminContacts => _adminContacts;

  List<dynamic> _employeeContacts = [];
  List<dynamic> get employeeContacts => _employeeContacts;

  List<dynamic> _announcements = [];
  List<dynamic> get announcements => _announcements;

  List<dynamic> _payslipRequests = [];
  List<dynamic> get payslipRequests => _payslipRequests;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmittingEOD = false;
  bool get isSubmittingEOD => _isSubmittingEOD;

  bool _isApplyingLeave = false;
  bool get isApplyingLeave => _isApplyingLeave;

  bool _isSendingMessage = false;
  bool get isSendingMessage => _isSendingMessage;

  String? _error;
  String? get error => _error;

  String? _userRole;
  String? _userId; // Store userId for cache key generation
  String? _previousUserId; // Store previous userId to detect changes
  String? _lastToken; // Store last token to detect token changes
  bool _isInitialized = false;
  bool _isRefreshing = false;

  String? _currentUserId;

  bool _dashboardLoadedFromCache = false;
  bool _profileLoadedFromCache = false;

  bool? _isBadgeSupported;
  int _lastBadgeCount = -1;

  String? _currentChatPartnerId;
  String? get currentChatPartnerId => _currentChatPartnerId;

  void setCurrentChatPartner(String? userId) {
    _currentChatPartnerId = userId;
  }

  Map<String, dynamic> _convertToMapStringDynamic(dynamic data) {
    if (data == null) {
      throw Exception('Data is null');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      try {
        final jsonString = jsonEncode(data);
        final decoded = jsonDecode(jsonString);

        if (decoded is Map) {
          return _convertMapRecursive(decoded);
        } else {
          throw Exception('Decoded data is not a Map: ${decoded.runtimeType}');
        }
      } catch (jsonError) {
        return _convertMapRecursive(data);
      }
    }

    throw Exception('Data is not a Map: ${data.runtimeType}');
  }

  Map<String, dynamic> _convertMapRecursive(dynamic map) {
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

  void setUserRole(String role) {
    _userRole = role;
  }

  void updateToken(String token) {
    _token = token;
  }

  String? _getUserId([String? token]) {
    final tokenToUse = token ?? _token;
    if (tokenToUse == null) return null;
    try {
      final payload = Jwt.parseJwt(tokenToUse);
      return (payload['userId'] ?? payload['id'])?.toString();
    } catch (e) {
      return null;
    }
  }

  bool _hasUserIdChanged(String? newUserId) {
    if (newUserId == null) return false;

    final hasDataInMemory =
        _employeeProfile != null ||
        _dashboardData != null ||
        _payslips.isNotEmpty ||
        _currentSalary != null;

    if (_currentUserId == null) {
      if (hasDataInMemory) {
        _employeeProfile = null;
        _dashboardData = null;
        _payslips = [];
        _currentSalary = null;
        _eodEntries = [];
        _leaveRequests = [];
        _leaveBalance = null;
        _leaveStatistics = null;
        _messages = [];
        _announcements = [];
        _payslipRequests = [];
        _dashboardLoadedFromCache = false;
        _profileLoadedFromCache = false;
        _messagesLoadedFromCache = false;
        _currentUserId = newUserId;
        _notify();
        return true;
      }
      _currentUserId = newUserId;
      return false;
    }

    if (_currentUserId != newUserId) {
      _employeeProfile = null;
      _dashboardData = null;
      _payslips = [];
      _currentSalary = null;
      _eodEntries = [];
      _leaveRequests = [];
      _leaveBalance = null;
      _leaveStatistics = null;
      _messages = [];
      _announcements = [];
      _payslipRequests = [];
      _dashboardLoadedFromCache = false;
      _profileLoadedFromCache = false;
      _messagesLoadedFromCache = false;
      _currentUserId = newUserId;
      _notify();
      return true;
    }
    return false;
  }

  Future<void> _ensureAuth() async {
    try {
      final storedToken = await _storage.read(key: 'jwt');
      if (storedToken != null) {
        updateToken(storedToken);
      } else {
        _token = null;

        throw Exception('User not authenticated');
      }
    } catch (e) {
      _token = null;
      throw Exception('Authentication failed');
    }
  }

  Future<void> refreshAllData(String token, {bool forceRefresh = false}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    try {
      await _ensureAuth();
      final authToken = _token ?? token;
      final userId = _getUserId(authToken);

      final role = _userRole ?? 'employee';
      _userRole ??= role;

      if (!forceRefresh && _dashboardData == null) {
        try {
          final cachedDashboard = await HiveCacheService.getCachedDashboard(
            role,
            userId: userId,
          );
          if (cachedDashboard != null) {
            _dashboardData = cachedDashboard;
            _dashboardLoadedFromCache = true;
            _notify();
          }
        } catch (e) {}
      }

      if (!forceRefresh && _employeeProfile == null) {
        try {
          final cachedProfile = await HiveCacheService.getCachedProfile(
            role,
            userId: userId,
          );
          if (cachedProfile != null) {
            try {
              final cachedData = _convertToMapStringDynamic(cachedProfile);
              _employeeProfile = Employee.fromJson(cachedData);
              _profileLoadedFromCache = true;
              _notify();
            } catch (conversionError) {}
          }
        } catch (e) {}
      }

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline &&
          (!forceRefresh ||
              (_dashboardLoadedFromCache || _profileLoadedFromCache))) {
        _isRefreshing = false;
        _notify();
        return;
      }

      if (_isInitialized && !forceRefresh) {}

      _isInitialized = true;

      final futures = <Future>[];

      if (isOnline || forceRefresh) {
        final userId = _getUserId(authToken);

        final cachedDashboard = await HiveCacheService.getCachedDashboard(
          role,
          userId: userId,
        );
        final hasCachedDashboard = cachedDashboard != null;

        if ((forceRefresh && !_dashboardLoadedFromCache) ||
            (_dashboardData == null && !hasCachedDashboard)) {
          futures.add(
            fetchEmployeeDashboardSummary(
              token,
              forceRefresh: forceRefresh,
            ).catchError((e) {}),
          );
        }
      }

      if (isOnline || forceRefresh) {
        final cachedProfile = await HiveCacheService.getCachedProfile(role);
        final hasCachedProfile = cachedProfile != null;

        if ((forceRefresh && !_profileLoadedFromCache) ||
            (_employeeProfile == null && !hasCachedProfile)) {
          futures.add(
            loadEmployeeProfile(
              token,
              forceRefresh: forceRefresh,
            ).catchError((e) {}),
          );
        }
      }

      if (isOnline || forceRefresh) {
        futures.add(loadPayslips(token).catchError((e) {}));
        futures.add(loadCurrentSalary(token).catchError((e) {}));

        futures.add(loadHRContacts(token).catchError((e) {}));
        futures.add(loadAdminContacts(token).catchError((e) {}));

        futures.add(loadLeaveBalance(token).catchError((e) {}));

        futures.add(checkMessagingPermission(token).catchError((e) {}));
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures, eagerError: false);
      }

      try {
        await loadAnnouncements(token, forceRefresh: forceRefresh);
      } catch (e) {}
    } catch (e) {
      if (!e.toString().toLowerCase().contains('socketexception') &&
          !e.toString().toLowerCase().contains('no internet connection') &&
          !e.toString().toLowerCase().contains('authentication')) {
        _error = e.toString();
      }
    } finally {
      _isRefreshing = false;
      _notify();
    }
  }

  void clearData() {
    _dashboardData = null;
    _eodEntries = [];
    _leaveRequests = [];
    _leaveBalance = null;
    _leaveStatistics = null;
    _blackoutDates = [];
    _payslips = [];
    _messages = [];
    _hrContacts = [];
    _adminContacts = [];
    _announcements = [];
    _payslipRequests = [];
    _messagingPermissions = null;
    _messagingPermissions = null;
    _error = null;
    _salaryBreakdown = null;
    _employeeProfile = null;
    _isInitialized = false;
    _isRefreshing = false;
    _token = null;
    _userRole = null;
    _currentUserId = null;
    _dashboardLoadedFromCache = false;
    _profileLoadedFromCache = false;
    _messagesLoadedFromCache = false;
    _notify();
  }

  Future<void> clearCache(String dataType) async {
    await HiveCacheService.clearCacheForRole(_userRole ?? 'employee', dataType);
  }

  Future<void> clearAllCache() async {
    await HiveCacheService.clearAllCacheForRole(_userRole ?? 'employee');
  }

  Future<void> refreshDashboardData(String token) async {
    try {
      await fetchEmployeeDashboardSummary(token, forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> forceRefreshDashboard(String token) async {
    try {
      await HiveCacheService.clearAllCache();

      _dashboardData = null;
      _employeeProfile = null;
      _messages = [];
      _announcements = [];

      await refreshAllData(token, forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }
}

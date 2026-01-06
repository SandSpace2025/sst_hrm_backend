import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/data/repositories/admin_repository.dart';
import 'package:hrm_app/data/repositories/messaging_repository.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/data/models/admin_profile.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/data/models/hr_model.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first

class AdminProvider with ChangeNotifier {
  final AdminRepository _adminRepository = AdminRepository();
  final MessagingRepository _messagingRepository = MessagingRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  String? _userId;
  String? _userRole;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  AdminProfile? _adminProfile;
  AdminProfile? get adminProfile => _adminProfile;

  List<dynamic> _users = [];
  List<dynamic> get users => _users;

  List<Employee> _employees = [];
  List<Employee> get employees => _employees;

  List<HR> _hrUsers = [];
  List<HR> get hrUsers => _hrUsers;

  List<Map<String, dynamic>> _messagingPermissionRequests = [];
  List<Map<String, dynamic>> get messagingPermissionRequests =>
      _messagingPermissionRequests;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreatingUser = false;
  bool get isCreatingUser => _isCreatingUser;

  bool _isUpdatingUser = false;
  bool get isUpdatingUser => _isUpdatingUser;

  bool _isDeletingUser = false;
  bool get isDeletingUser => _isDeletingUser;

  String? _error;
  String? get error => _error;

  String? _lastFetchedRole;

  String? get userRole => _userRole;
  String? get userId => _userId;

  String? _currentChatPartnerId;
  String? get currentChatPartnerId => _currentChatPartnerId;

  void setCurrentChatPartner(String? userId) {
    _currentChatPartnerId = userId;
  }

  final Set<String> _unreadConversations = {};
  int get unreadMessagesCount => _unreadConversations.length;

  bool hasUnreadMessages(String userId) {
    return _unreadConversations.contains(userId);
  }

  bool? _isBadgeSupported;

  int _lastBadgeCount = -1;

  Future<void> _updateAppBadge() async {
    try {
      if (_isBadgeSupported == null) {
        _isBadgeSupported = await AppBadgePlus.isSupported();
      }

      final count = _unreadConversations.length;
      if (count == _lastBadgeCount) return;

      if (_isBadgeSupported == true) {
        await AppBadgePlus.updateBadge(count > 0 ? count : 0);
      } else {
        await AppBadgePlus.updateBadge(count > 0 ? count : 0);
      }
      _lastBadgeCount = count;
    } catch (e) {
      // debugPrint('Error updating app badge: $e');
    }
  }

  void addUnreadConversation(String senderId) {
    if (senderId != _currentChatPartnerId) {
      if (!_unreadConversations.contains(senderId)) {
        _unreadConversations.add(senderId);
        _updateAppBadge();
        notifyListeners();
      }
    }
  }

  void removeUnreadConversation(String senderId) {
    if (_unreadConversations.contains(senderId)) {
      _unreadConversations.remove(senderId);
      _updateAppBadge();
      notifyListeners();
    }
  }

  void setUnreadConversations(List<dynamic> senderIds) {
    debugPrint('AdminProvider: Setting unread conversations: $senderIds');
    _unreadConversations.clear();
    for (var id in senderIds) {
      if (id != null) {
        _unreadConversations.add(id.toString());
      }
    }
    _updateAppBadge();
    notifyListeners();
  }

  void setUserRole(String role) {
    _userRole = role;
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

  void updateToken(String token) {
    _token = token;
  }

  Future<void> _ensureAuth() async {
    if (_token != null) {
      return;
    }

    try {
      final storedToken = await _storage.read(key: 'jwt');
      if (storedToken != null) {
        updateToken(storedToken);
      } else {
        throw Exception('User not authenticated');
      }
    } catch (e) {
      throw Exception('Authentication failed');
    }
  }

  Future<void> fetchDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline && forceRefresh) {
      _error = 'No internet connection';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardData = await _adminRepository.getDashboardSummary(
        authToken,
        forceRefresh: forceRefresh,
      );

      final unreadSenderIds = _dashboardData?['unreadSenderIds'];
      if (unreadSenderIds is List) {
        setUnreadConversations(unreadSenderIds);
      }

      _error = null;
    } catch (e) {
      if (_dashboardData == null) {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminProfile(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline && forceRefresh) {
      _error = 'No internet connection';
      notifyListeners();
      return;
    }

    try {
      final response = await _adminRepository.getProfile(
        authToken,
        forceRefresh: forceRefresh,
      );

      _adminProfile = AdminProfile.fromJson(response);
      if (_adminProfile != null) {
        _userId = _adminProfile!.id;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshAllData(String token, {bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        fetchDashboardSummary(token, forceRefresh: forceRefresh),
        loadAdminProfile(token, forceRefresh: forceRefresh),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUsersByRole(String role, String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      return;
    }

    _isLoading = true;
    _error = null;
    _lastFetchedRole = role;
    notifyListeners();
    try {
      final newUsers = await _adminRepository.getUsersByRole(role, authToken);

      _users = List<dynamic>.from(newUsers);
    } catch (e) {
      _error = e.toString();
      _users = [];
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUser(
    String name,
    String email,
    String password,
    String role,
    String token, {
    String? subOrganisation,
    String? employeeId,
    String? jobTitle,
    String? bloodGroup,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isCreatingUser = true;
    _error = null;
    notifyListeners();
    try {
      await _adminRepository.createUser(
        name,
        email,
        password,
        role,
        authToken,
        subOrganisation: subOrganisation,
        employeeId: employeeId,
        jobTitle: jobTitle,
        bloodGroup: bloodGroup,
      );

      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (isOnline && _lastFetchedRole != null) {
        await fetchUsersByRole(_lastFetchedRole!, authToken);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isCreatingUser = false;
      notifyListeners();
    }
  }

  Future<void> updateUser({
    required String userId,
    required Map<String, dynamic> data,
    required String token,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isUpdatingUser = true;
    _error = null;
    notifyListeners();
    try {
      await _adminRepository.updateUser(userId, data, authToken);

      final index = _users.indexWhere((user) {
        if (user is Map && user['user'] != null) {
          return user['user']['_id'] == userId;
        }
        return false;
      });

      if (index != -1) {
        if (data.containsKey('name')) {
          _users[index]['name'] = data['name'];
        }
        if (data.containsKey('phone')) {
          _users[index]['phone'] = data['phone'];
        }
        if (data.containsKey('email')) {
          _users[index]['email'] = data['email'];
        }
        if (data.containsKey('jobTitle')) {
          _users[index]['jobTitle'] = data['jobTitle'];
        }
        if (data.containsKey('bloodGroup')) {
          _users[index]['bloodGroup'] = data['bloodGroup'];
        }
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isUpdatingUser = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser({
    required String userId,
    required String token,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isDeletingUser = true;
    _error = null;
    notifyListeners();
    try {
      await _adminRepository.deleteUser(userId, authToken);

      _users.removeWhere((user) {
        if (user is Map && user['user'] != null) {
          return user['user']['_id'] == userId;
        }
        return false;
      });

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isDeletingUser = false;
      notifyListeners();
    }
  }

  Future<void> refreshUsers(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      return;
    }

    if (_lastFetchedRole != null) {
      await fetchUsersByRole(_lastFetchedRole!, authToken);
    }
  }

  Future<void> loadEmployees(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _employees.isNotEmpty && search == null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      _isLoading = false;

      if (_employees.isNotEmpty) {
        notifyListeners();
      }
      return;
    }

    try {
      final response = await _messagingRepository.getEmployeesForMessaging(
        authToken,
        search: search,
        page: 1,
        limit: 100,
      );

      final List<dynamic> employeesData = response['employees'] ?? [];
      _employees = employeesData.map((data) {
        final employeeData = _convertToMapStringDynamic(data);
        return Employee.fromJson(employeeData);
      }).toList();
      _error = null;
    } on SocketException {
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (_employees.isEmpty) {
        _employees = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHRUsers(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _hrUsers.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      _isLoading = false;

      if (_hrUsers.isNotEmpty) {
        notifyListeners();
      }
      return;
    }

    try {
      final response = await _messagingRepository.getHRForMessaging(
        authToken,
        search: search,
        page: 1,
        limit: 100,
      );

      final List<dynamic> hrUsersData = response['hrUsers'] ?? [];
      _hrUsers = hrUsersData.map((data) {
        final hrData = _convertToMapStringDynamic(data);
        return HR.fromJson(hrData);
      }).toList();
      _error = null;
    } on SocketException {
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (_hrUsers.isEmpty) {
        _hrUsers = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _dashboardData = null;
    _users = [];
    _employees = <Employee>[];
    _hrUsers = <HR>[];
    _messagingPermissionRequests = <Map<String, dynamic>>[];
    _error = null;
    _lastFetchedRole = null;
    _userRole = null;
    _userId = null;
    _adminProfile = null;
    _unreadConversations.clear();
    _currentChatPartnerId = null;
    notifyListeners();
  }

  Future<void> clearCache(String dataType) async {
    await HiveCacheService.clearCacheForRole('admin', dataType);
  }

  Future<void> clearAllCache() async {
    await HiveCacheService.clearAllCache();
  }

  Future<void> loadMessagingPermissionRequests(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _adminRepository.getMessagingPermissionRequests(
        authToken,
      );
      _messagingPermissionRequests = List<Map<String, dynamic>>.from(
        response['requests'] ?? [],
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> grantMessagingPermission(
    String token,
    String employeeId, {
    int durationHours = 48,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      await _adminRepository.grantMessagingPermission(
        authToken,
        employeeId,
        durationHours: durationHours,
      );

      _messagingPermissionRequests.removeWhere(
        (request) => request['_id'] == employeeId,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> revokeMessagingPermission(
    String token,
    String employeeId,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      await _adminRepository.revokeMessagingPermission(authToken, employeeId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadActiveMessagingPermissions(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _adminRepository.getActiveMessagingPermissions(authToken);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<dynamic> _messages = [];
  List<dynamic> get messages => _messages;

  Future<void> sendMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _error = null;
    notifyListeners();
    try {
      await _messagingRepository.sendAdminMessageToEmployee(
        employeeId,
        subject,
        content,
        authToken,
        priority: priority,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _error = null;
    notifyListeners();
    try {
      await _messagingRepository.sendAdminMessageToHR(
        hrId,
        subject,
        content,
        authToken,
        priority: priority,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getConversation(
    String userId,
    String userType,
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _messagingRepository.getAdminConversation(
        userId,
        userType,
        authToken,
        forceRefresh: forceRefresh,
      );

      List<dynamic> extracted = [];
      final dynamic conversation = response['conversation'];
      final dynamic messages = response['messages'];

      if (conversation is List) {
        extracted = conversation;
      } else if (messages is List) {
        extracted = messages;
      } else if (conversation is Map && conversation['messages'] is List) {
        extracted = List<dynamic>.from(conversation['messages']);
      }

      _messages = List<dynamic>.from(extracted);

      _isLoading = false;
      _error = null;
      notifyListeners();
      return response;
    } catch (e) {
      if (_messages.isEmpty) {
        _error = e.toString();
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    debugPrint(
      'AdminProvider: Marking conversation as seen for userId: $userId, type: $userType',
    );
    try {
      await _messagingRepository.markAdminConversationAsSeen(
        userId,
        userType,
        token,
      );
      debugPrint(
        'AdminProvider: API call successful. Removing from local unread.',
      );
      removeUnreadConversation(userId);
    } catch (e) {
      debugPrint(
        'AdminProvider: API call failed: $e. Optimistically removing.',
      );
      if (userId.isNotEmpty) {
        removeUnreadConversation(userId);
      }
    }
  }
}

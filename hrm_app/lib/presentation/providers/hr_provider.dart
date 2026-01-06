import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/data/models/hr_model.dart';
import 'package:hrm_app/data/repositories/hr_repository.dart';
import 'package:hrm_app/data/repositories/messaging_repository.dart';
import 'package:hrm_app/data/repositories/payroll_repository.dart';
import 'package:hrm_app/data/repositories/announcement_repository.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class HRProvider with ChangeNotifier {
  final HRRepository _hrRepository = HRRepository();
  final MessagingRepository _messagingRepository = MessagingRepository();
  final PayrollRepository _payrollRepository = PayrollRepository();
  final AnnouncementRepository _announcementRepository =
      AnnouncementRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _token;
  String? _userId;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  HR? _hrProfile;
  HR? get hrProfile => _hrProfile;

  List<dynamic> _employees = [];
  List<dynamic> get employees => _employees;

  List<Employee> _employeesForMessaging = [];
  List<Employee> get employeesForMessaging => _employeesForMessaging;

  List<dynamic> _adminsForMessaging = [];
  List<dynamic> get adminsForMessaging => _adminsForMessaging;

  List<dynamic> _messages = [];
  List<dynamic> get messages => _messages;

  List<dynamic> _announcements = [];
  List<dynamic> get announcements => _announcements;

  List<Map<String, dynamic>> _payslipRequests = [];
  List<Map<String, dynamic>> get payslipRequests => _payslipRequests;

  Map<String, dynamic> _payslipRequestStats = {};
  Map<String, dynamic> get payslipRequestStats => _payslipRequestStats;

  List<Map<String, dynamic>> _payslipApprovalHistory = [];
  List<Map<String, dynamic>> get payslipApprovalHistory =>
      _payslipApprovalHistory;

  Map<String, dynamic>? _employeeLeaveData;
  Map<String, dynamic>? get employeeLeaveData => _employeeLeaveData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isCreatingEmployee = false;
  bool get isCreatingEmployee => _isCreatingEmployee;

  bool _isUpdatingEmployee = false;
  bool get isUpdatingEmployee => _isUpdatingEmployee;

  bool _isDeletingEmployee = false;
  bool get isDeletingEmployee => _isDeletingEmployee;

  String? _error;
  String? get error => _error;

  String? _userRole;
  String? get userRole => _userRole;

  String? get userId => _userId;

  bool _dashboardLoadedFromCache = false;
  bool _profileLoadedFromCache = false;

  final Set<String> _unreadConversations = {};
  int get unreadMessagesCount => _unreadConversations.length;

  int get pendingLeavesCount {
    if (_dashboardData != null && _dashboardData!['pendingLeaves'] != null) {
      if (_dashboardData!['pendingLeaves'] is int) {
        return _dashboardData!['pendingLeaves'];
      } else if (_dashboardData!['pendingLeaves'] is List) {
        return (_dashboardData!['pendingLeaves'] as List).length;
      }
    }
    return 0;
  }

  String? _currentChatPartnerId;
  String? get currentChatPartnerId => _currentChatPartnerId;

  void setCurrentChatPartner(String? userId) {
    _currentChatPartnerId = userId;
  }

  DateTime? _lastLocalUnreadUpdate;

  bool? _isBadgeSupported;

  int _lastBadgeCount = -1;

  void _updateAppBadge() async {
    try {
      if (_isBadgeSupported == null) {
        _isBadgeSupported = await AppBadgePlus.isSupported();
        debugPrint('AppBadgePlus Supported: $_isBadgeSupported');
      }

      final count = _unreadConversations.length;
      if (count == _lastBadgeCount) return;

      if (_isBadgeSupported == true) {
        debugPrint('Updating App Badge to: $count');
        await AppBadgePlus.updateBadge(count > 0 ? count : 0);
      } else {
        debugPrint(
          'AppBadgePlus reported not supported, trying force update to: $count',
        );
        await AppBadgePlus.updateBadge(count > 0 ? count : 0);
      }
      _lastBadgeCount = count;
    } catch (e) {
      debugPrint('Error updating app badge: $e');
    }
  }

  void setUnreadConversations(List<dynamic> senderIds) {
    if (senderIds.isEmpty) {
      if (_lastLocalUnreadUpdate != null &&
          DateTime.now().difference(_lastLocalUnreadUpdate!).inSeconds < 5) {
        return;
      }
      if (_unreadConversations.isNotEmpty) {
        _unreadConversations.clear();
        _updateAppBadge();
        notifyListeners();
      }
      return;
    }

    _unreadConversations.clear();
    for (final id in senderIds) {
      if (id != null && id.toString().isNotEmpty) {
        _unreadConversations.add(id.toString());
      }
    }
    _updateAppBadge();
    notifyListeners();
  }

  void addUnreadConversation(String senderId) {
    if (senderId.isEmpty) return;
    if (_currentChatPartnerId == senderId) return;
    if (!_unreadConversations.contains(senderId)) {
      _unreadConversations.add(senderId);
      _lastLocalUnreadUpdate = DateTime.now();
      _updateAppBadge();
      notifyListeners();
    }
  }

  void removeUnreadConversation(String senderId) {
    if (_unreadConversations.contains(senderId)) {
      _unreadConversations.remove(senderId);
      _updateAppBadge();
      notifyListeners();
    }
  }

  void clearUnreadConversations() {
    _unreadConversations.clear();
    _updateAppBadge();
    notifyListeners();
  }

  bool hasUnreadMessages(String senderId) {
    return _unreadConversations.contains(senderId);
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

  String? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);

      if (payloadMap is Map<String, dynamic>) {
        return payloadMap['id'] ?? payloadMap['_id'];
      }
    } catch (e) {}
    return null;
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

  Future<void> fetchHRDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    // if (_isRefreshing) return; // Removed to allow refreshAllData to call this

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline && !forceRefresh) {
      final role = _userRole ?? 'hr';
      final cached = await HiveCacheService.getCachedDashboard(
        role,
        userId: _userId,
      );
      if (cached != null) {
        _dashboardData = cached;
        _dashboardLoadedFromCache = true;

        // Ensure unread conversations are populated from cache
        final unreadSenderIds = _dashboardData?['unreadSenderIds'];
        if (unreadSenderIds is List) {
          setUnreadConversations(unreadSenderIds);
        }

        _error = null;

        notifyListeners();
        return;
      } else if (_dashboardData != null) {
        return;
      }

      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _hrRepository.getDashboardSummary(
        authToken,
        forceRefresh: forceRefresh,
      );
      _dashboardData = data;
      _dashboardLoadedFromCache = false;

      // Update Cache
      if (_dashboardData != null) {
        await HiveCacheService.cacheDashboard(
          'hr',
          _dashboardData!,
          userId: _userId,
        );
      }

      final unreadSenderIds = _dashboardData?['unreadSenderIds'];
      print('DEBUG: Unread Sender IDs from Server: $unreadSenderIds');
      if (unreadSenderIds is List) {
        setUnreadConversations(unreadSenderIds);
      }
      _error = null;
    } catch (e) {
      final role = _userRole ?? 'hr';
      final cached = await HiveCacheService.getCachedDashboard(
        role,
        userId: _userId,
      );
      if (cached != null) {
        _dashboardData = cached;
        _dashboardLoadedFromCache = true;

        // Ensure unread conversations are populated from cache
        final unreadSenderIds = _dashboardData?['unreadSenderIds'];
        if (unreadSenderIds is List) {
          setUnreadConversations(unreadSenderIds);
        }

        _error = isOnline
            ? null
            : (forceRefresh ? 'No internet connection' : null);
      } else {
        _error = e.toString();

        if (!isOnline) {
          _error = null;
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHRProfile(String token, {bool forceRefresh = false}) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    // Extract userId from token for cache key
    _userId = _extractUserIdFromToken(authToken);

    final role = _userRole ?? 'hr';

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline && !forceRefresh) {
      final cached = await HiveCacheService.getCachedProfile(
        role,
        userId: _userId,
      );
      if (cached != null) {
        _hrProfile = HR.fromJson(Map<String, dynamic>.from(cached));
        _profileLoadedFromCache = true;

        notifyListeners();
        return;
      }
      return;
    }

    if (_hrProfile == null || forceRefresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final data = await _hrRepository.getProfile(
        authToken,
        forceRefresh: forceRefresh,
      );
      _hrProfile = HR.fromJson(Map<String, dynamic>.from(data));
      _profileLoadedFromCache = false;
      _error = null;
    } catch (e) {
      final cached = await HiveCacheService.getCachedProfile(role);
      if (cached != null) {
        _hrProfile = HR.fromJson(Map<String, dynamic>.from(cached));
        _profileLoadedFromCache = true;
      } else {
        if (isOnline || forceRefresh) {
          _error = e.toString();
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateHRProfilePic(String imageUrl) {
    if (_hrProfile != null) {
      _hrProfile = HR(
        id: _hrProfile!.id,
        name: _hrProfile!.name,
        email: _hrProfile!.email,
        phone: _hrProfile!.phone,
        subOrganisation: _hrProfile!.subOrganisation,
        profilePicture: imageUrl,
        employeeId: _hrProfile!.employeeId,
        jobTitle: _hrProfile!.jobTitle,
        user: _hrProfile!.user,
      );
      notifyListeners();
    }
  }

  Future<void> fetchEmployees(
    String token, {
    String? search,
    int page = 1,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _hrRepository.getEmployees(
        authToken,
        search: search,
        page: page,
      );

      _employees = List<dynamic>.from(response['employees'] ?? []);
    } catch (e) {
      _error = e.toString();
      _employees = [];
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEmployee(
    String name,
    String email,
    String password,
    String subOrganisation,
    String employeeId,
    String token, {
    String? jobTitle,
    String? phone,
    String? bloodGroup,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isCreatingEmployee = true;
    _error = null;
    notifyListeners();
    try {
      await _hrRepository.createEmployee(
        name,
        email,
        password,
        subOrganisation,
        employeeId,
        authToken,
        jobTitle: jobTitle,
        phone: phone,
        bloodGroup: bloodGroup,
      );

      await fetchEmployees(authToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isCreatingEmployee = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployee({
    required String employeeId,
    required Map<String, dynamic> data,
    required String token,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isUpdatingEmployee = true;
    _error = null;
    notifyListeners();
    try {
      await _hrRepository.updateEmployee(employeeId, data, authToken);

      final index = _employees.indexWhere((employee) {
        if (employee is Map && employee['_id'] != null) {
          return employee['_id'] == employeeId;
        }
        return false;
      });

      if (index != -1) {
        if (data.containsKey('name')) {
          _employees[index]['name'] = data['name'];
        }
        if (data.containsKey('phone')) {
          _employees[index]['phone'] = data['phone'];
        }
        if (data.containsKey('email')) {
          _employees[index]['email'] = data['email'];
        }
        if (data.containsKey('jobTitle')) {
          _employees[index]['jobTitle'] = data['jobTitle'];
        }
        if (data.containsKey('bloodGroup')) {
          _employees[index]['bloodGroup'] = data['bloodGroup'];
        }
        notifyListeners();
      } else {
        await fetchEmployees(authToken);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isUpdatingEmployee = false;
      notifyListeners();
    }
  }

  Future<void> deleteEmployee({
    required String employeeId,
    required String token,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isDeletingEmployee = true;
    _error = null;
    notifyListeners();
    try {
      await _hrRepository.deleteEmployee(employeeId, authToken);

      _employees.removeWhere((employee) {
        if (employee is Map && employee['_id'] != null) {
          return employee['_id'] == employeeId;
        }
        return false;
      });

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isDeletingEmployee = false;
      notifyListeners();
    }
  }

  void clearData() {
    _dashboardData = null;
    _hrProfile = null;
    _employees = [];
    _employeesForMessaging = <Employee>[];
    _adminsForMessaging = [];
    _messages = [];
    _announcements = [];
    _payslipRequests = <Map<String, dynamic>>[];
    _payslipRequestStats = {};
    _payslipApprovalHistory = <Map<String, dynamic>>[];
    _error = null;
    _userRole = null;
    _userId = null;
    _dashboardLoadedFromCache = false;
    _profileLoadedFromCache = false;
    _unreadConversations.clear();
    _currentChatPartnerId = null;
    notifyListeners();
  }

  Future<void> refreshEmployees(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    await fetchEmployees(authToken);
  }

  Future<void> loadEmployeesForMessaging(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _employeesForMessaging.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _messagingRepository.getHREmployeesForMessaging(
        authToken,
        search: search,
      );
      final List<dynamic> employeesData = response['employees'] ?? [];
      _employeesForMessaging = employeesData
          .map((data) => Employee.fromJson(data))
          .toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (_employeesForMessaging.isEmpty) {
        _employeesForMessaging = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminsForMessaging(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _adminsForMessaging.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _messagingRepository.getHRAdminsForMessaging(
        authToken,
        search: search,
      );
      _adminsForMessaging = List<dynamic>.from(response['admins'] ?? []);
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (_adminsForMessaging.isEmpty) {
        _adminsForMessaging = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHRMessages(String token, {int page = 1}) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _messagingRepository.getHRMessages(
        authToken,
        page: page,
      );
      _messages = List<dynamic>.from(response['messages'] ?? []);
    } catch (e) {
      _error = e.toString();
      _messages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAnnouncements(
    String token, {
    int page = 1,
    bool onlyMine = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _announcementRepository.getHRAnnouncements(
        authToken,
        page: page,
        onlyMine: onlyMine,
      );
      _announcements = List<dynamic>.from(response['announcements'] ?? []);
    } catch (e) {
      _error = e.toString();
      _announcements = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateHRProfile(Map<String, dynamic> data, String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _hrRepository.updateProfile(data, authToken);

      await loadHRProfile(authToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadProfileImage(File imageFile, String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        throw Exception('No internet connection');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/api/hr/profile/image'),
      );

      request.headers['Authorization'] = 'Bearer $authToken';

      final String fileExtension = imageFile.path.split('.').last.toLowerCase();
      request.files.add(
        await http.MultipartFile.fromPath(
          'profileImage',
          imageFile.path,
          contentType: MediaType(
            'image',
            fileExtension == 'jpg' ? 'jpeg' : fileExtension,
          ),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['imageUrl'];
        updateHRProfilePic(imageUrl);

        // Also update local cache if possible
        // Also update local cache if possible

        // Note: We might want to update the cache here, but simpler to just update the in-memory object
        // and let the next fetch handle full sync, or manually update cache.
        // For now, updating in-memory via updateHRProfilePic is enough as it triggers UI update.
      } else {
        String errorMessage = 'Unknown error';
        try {
          if (response.body.startsWith('<!DOCTYPE html>') ||
              response.body.startsWith('<html')) {
            errorMessage =
                'Server returned HTML instead of JSON. Check if server is running correctly.';
          } else {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? 'Unknown error';
          }
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      await _messagingRepository.sendHRMessageToEmployee(
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

  Future<void> sendMessageToAdmin(
    String adminId,
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
      await _messagingRepository.sendHRMessageToAdmin(
        adminId,
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

    final currentUserRole = 'hr';
    final conversationKey =
        '${currentUserRole}_${userId}_${userType.toLowerCase()}';

    if (!forceRefresh) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _isLoading = false;
        _error = null;

        return {'messages': _messages, 'conversation': _messages};
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _error = null;
      } else {
        _messages = [];
        _error = null;

        return {'messages': _messages, 'conversation': _messages};
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _messagingRepository.getHRConversation(
        userId,
        userType,
        authToken,
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
      } else {
        final dynamic data = response['data'];
        if (data is List) {
          extracted = data;
        } else if (data is Map && data['messages'] is List) {
          extracted = List<dynamic>.from(data['messages']);
        }
      }

      _messages = List<dynamic>.from(extracted);

      await HiveCacheService.cacheConversationMessages(
        conversationKey,
        _messages,
      );

      _isLoading = false;
      _error = null;
      notifyListeners();
      return response;
    } catch (e) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _error = null;
      } else {
        _error = e.toString();
        _messages = [];
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markMessageAsRead(String messageId, String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        return;
      }

      await _messagingRepository.markHRMessageAsRead(messageId, authToken);

      if (isOnline) {
        await fetchHRDashboardSummary(authToken);
      }
    } catch (e) {}
  }

  Future<void> markConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        return;
      }

      await _messagingRepository.markHRConversationAsSeen(
        userId,
        userType,
        authToken,
      );

      if (isOnline) {
        await fetchHRDashboardSummary(authToken, forceRefresh: true);
      }
    } catch (e) {}
  }

  Future<void> refreshAllData(String token, {bool forceRefresh = false}) async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    try {
      final role = _userRole ?? 'hr';
      _userRole ??= role;

      if (!forceRefresh && _dashboardData == null) {
        try {
          final cachedDashboard = await HiveCacheService.getCachedDashboard(
            role,
          );
          if (cachedDashboard != null) {
            _dashboardData = cachedDashboard;
            _dashboardLoadedFromCache = true; // Mark as loaded from cache

            // Ensure unread conversations are populated from cache
            // final unreadSenderIds = _dashboardData?['unreadSenderIds'];
            // if (unreadSenderIds is List) {
            //   setUnreadConversations(unreadSenderIds);
            // }

            notifyListeners();
          }
        } catch (e) {}
      }

      if (!isOnline && !forceRefresh && _hrProfile == null) {
        try {
          final cachedProfile = await HiveCacheService.getCachedProfile(
            role,
            userId: _userId,
          );
          if (cachedProfile != null) {
            try {
              final cachedData = _convertToMapStringDynamic(cachedProfile);
              _hrProfile = HR.fromJson(cachedData);
              _profileLoadedFromCache = true;
              notifyListeners();
            } catch (conversionError) {}
          }
        } catch (e) {}
      }

      if (!isOnline &&
          (!forceRefresh ||
              (_dashboardLoadedFromCache || _profileLoadedFromCache))) {
        _isRefreshing = false;
        notifyListeners();
        return;
      }

      final futures = <Future>[];

      if (isOnline) {
        final cachedDashboard = await HiveCacheService.getCachedDashboard(role);
        final hasCachedDashboard = cachedDashboard != null;

        // Fetch if forced, OR if no data, OR if current data is from cache (Stale-While-Revalidate)
        if (forceRefresh ||
            _dashboardData == null ||
            _dashboardLoadedFromCache ||
            (_dashboardData == null && !hasCachedDashboard)) {
          futures.add(
            fetchHRDashboardSummary(
              token,
              forceRefresh: forceRefresh,
            ).catchError((e) {}),
          );
        }
      }

      if (isOnline) {
        final cachedProfile = await HiveCacheService.getCachedProfile(role);
        final hasCachedProfile = cachedProfile != null;

        if ((forceRefresh && !_profileLoadedFromCache) ||
            (_hrProfile == null && !hasCachedProfile)) {
          futures.add(
            loadHRProfile(token, forceRefresh: forceRefresh).catchError((e) {}),
          );
        }
      }

      if (isOnline) {
        futures.add(loadEmployeesForMessaging(token).catchError((e) {}));
        futures.add(loadAdminsForMessaging(token).catchError((e) {}));
        futures.add(loadAnnouncements(token).catchError((e) {}));

        if (forceRefresh || _payslipRequests.isEmpty) {
          futures.add(
            loadPayslipRequests(
              token,
              forceRefresh: forceRefresh,
            ).catchError((e) {}),
          );
        }
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures, eagerError: false);
      }
    } catch (e) {
      if (!e.toString().toLowerCase().contains('socketexception') &&
          !e.toString().toLowerCase().contains('no internet connection') &&
          !e.toString().toLowerCase().contains('authentication')) {
        _error = e.toString();
      }
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> createAnnouncement(
    String title,
    String message,
    String token, {
    String audience = 'employees',
    String priority = 'normal',
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _announcementRepository.createHRAnnouncement(
        title,
        message,
        authToken,
        audience: audience,
        priority: priority,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getEmployeeLeaveData(
    String token,
    String employeeId, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _hrRepository.getEmployeeLeaveData(
        authToken,
        employeeId,
      );
      _employeeLeaveData = response;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateEmployeeLeaveData(
    String token,
    String employeeId,
    Map<String, dynamic> leaveData,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _hrRepository.updateEmployeeLeaveData(
        authToken,
        employeeId,
        leaveData,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearCache(String dataType) async {
    await HiveCacheService.clearCacheForRole(dataType, _userRole ?? 'hr');
  }

  Future<void> clearAllCache() async {
    await HiveCacheService.clearAllCache();
  }

  Future<void> loadPayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _payrollRepository.getHRPayslipRequests(
        authToken,
        page: page,
        limit: limit,
        status: status,
      );

      _payslipRequests = (response['requests'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayslipRequestStats(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _payrollRepository.getPayslipRequestStats(
        authToken,
      );
      _payslipRequestStats = response;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> processPayslipWithBasePay(
    String token,
    String requestId,
    double basePay, {
    double bonus = 0.0,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _payrollRepository.processPayslipWithBasePay(authToken, requestId, {
        'basePay': basePay,
        'bonus': bonus,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePayslipRequestStatus(
    String token,
    String requestId,
    String status, {
    String? payslipUrl,
    String? rejectionReason,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final statusData = <String, dynamic>{'status': status};

      if (payslipUrl != null) {
        statusData['payslipUrl'] = payslipUrl;
      }

      if (rejectionReason != null) {
        statusData['rejectionReason'] = rejectionReason;
      }

      await _payrollRepository.updatePayslipRequestStatus(
        authToken,
        requestId,
        statusData,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayslipApprovalHistory(
    String token, {
    int page = 1,
    int limit = 20,
    String? employeeName,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _error = null;
    notifyListeners();

    try {
      final response = await _payrollRepository.getPayslipApprovalHistory(
        authToken,
        page: page,
        limit: limit,
        employeeName: employeeName,
      );

      _payslipApprovalHistory = List<Map<String, dynamic>>.from(
        response['history'] ?? [],
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void handlePayslipRequestCreated(Map<String, dynamic> data) {
    if (_token != null) {
      loadPayslipRequests(_token!, forceRefresh: true).catchError((e) {});
    }
  }

  void handlePayslipRequestApproved(Map<String, dynamic> data) {
    _payslipRequests.removeWhere(
      (request) => request['_id'] == data['requestId'],
    );

    notifyListeners();
  }

  void handlePayslipRequestRejected(Map<String, dynamic> data) {
    _payslipRequests.removeWhere(
      (request) => request['_id'] == data['requestId'],
    );

    notifyListeners();
  }

  void handleEmployeeCreated(Map<String, dynamic> data) {}

  void handleEmployeeUpdated(Map<String, dynamic> data) {
    final employeeId = data['employee']['_id'];
    final index = _employees.indexWhere((emp) => emp['_id'] == employeeId);
    if (index != -1) {
      _employees[index] = data['employee'];
      notifyListeners();
    }
  }

  void handleEmployeeDeleted(Map<String, dynamic> data) {
    final employeeId = data['employee']['_id'];
    _employees.removeWhere((emp) => emp['_id'] == employeeId);
    notifyListeners();
  }

  void handleLeaveRequestCreated(Map<String, dynamic> data) {}

  void handleLeaveRequestApproved(Map<String, dynamic> data) {
    decrementPendingLeavesCount();
  }

  void handleLeaveRequestRejected(Map<String, dynamic> data) {
    decrementPendingLeavesCount();
  }

  void handleMessageReceived(Map<String, dynamic> data) {
    _messages.insert(0, data['message']);
    notifyListeners();
  }

  void handleAnnouncementCreated(Map<String, dynamic> data) {
    _announcements.insert(0, data['announcement']);
    notifyListeners();
  }

  void handleAnnouncementUpdated(Map<String, dynamic> data) {
    final announcementId = data['announcement']['_id'];
    final index = _announcements.indexWhere(
      (ann) => ann['_id'] == announcementId,
    );
    if (index != -1) {
      _announcements[index] = data['announcement'];
      notifyListeners();
    }
  }

  void handleAnnouncementDeleted(Map<String, dynamic> data) {
    final announcementId = data['announcement']['_id'];
    _announcements.removeWhere((ann) => ann['_id'] == announcementId);
    notifyListeners();
  }

  void setupWebSocketListeners(BuildContext context) {
    final webSocketProvider = Provider.of<WebSocketProvider>(
      context,
      listen: false,
    );

    webSocketProvider.messageStream.listen((data) {
      final event = data['event'] ?? '';
      if (event == 'interval_refresh') {
        _handleIntervalRefresh(context);
      } else {
        _handleRealtimeMessageUpdate(context, data);
      }
    });

    webSocketProvider.payslipStream.listen((data) {
      final event = data['event'] ?? '';
      if (event == 'interval_refresh') {
        _handleIntervalRefresh(context);
      } else {
        _handleRealtimePayslipUpdate(context, data);
      }
    });

    webSocketProvider.employeeStream.listen((data) {
      final event = data['event'] ?? '';
      if (event == 'interval_refresh') {
        _handleIntervalRefresh(context);
      } else {
        _handleRealtimeEmployeeUpdate(context, data);
      }
    });

    webSocketProvider.leaveStream.listen((data) {
      final event = data['event'] ?? '';
      if (event == 'interval_refresh') {
        _handleIntervalRefresh(context);
      } else {
        _handleRealtimeLeaveUpdate(context, data);
      }
    });

    webSocketProvider.announcementStream.listen((data) {
      final event = data['event'] ?? '';
      if (event == 'interval_refresh') {
        _handleIntervalRefresh(context);
      } else {
        _handleRealtimeAnnouncementUpdate(context, data);
      }
    });
  }

  void _handleIntervalRefresh(BuildContext context) {
    final now = DateTime.now();
    final lastRefresh = _lastRefreshTime;

    if (lastRefresh == null || now.difference(lastRefresh).inMinutes >= 5) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Connectivity()
            .checkConnectivity()
            .then((connectivity) {
              final isOnline =
                  connectivity.isNotEmpty &&
                  connectivity.any(
                    (result) => result != ConnectivityResult.none,
                  );

              if (isOnline && !_dashboardLoadedFromCache) {
                _lastRefreshTime = now;

                _refreshDashboardSafely(authProvider.token!);
              } else {}
            })
            .catchError((e) {});
      }
    }
  }

  Future<void> _refreshDashboardSafely(String token) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        return;
      }

      if (_dashboardLoadedFromCache) {
        return;
      }

      if (_dashboardData != null) {
        return;
      }

      await fetchHRDashboardSummary(token, forceRefresh: false);
    } catch (e) {}
  }

  DateTime? _lastRefreshTime;

  void _handleRealtimeMessageUpdate(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    handleMessageReceived(data);

    _triggerGentleRefresh(context);
  }

  void _handleRealtimePayslipUpdate(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final event = data['event'] ?? '';

    if (event.contains('created') ||
        event == 'payslipRequestCreated' ||
        event == 'payslip_request_created') {
      handlePayslipRequestCreated(data);
    } else if (event.contains('approved') ||
        event == 'payslipRequestApproved' ||
        event == 'payslip_request_approved') {
      handlePayslipRequestApproved(data);
    } else if (event.contains('rejected') ||
        event == 'payslipRequestRejected' ||
        event == 'payslip_request_rejected') {
      handlePayslipRequestRejected(data);
    }

    _triggerGentleRefresh(context);
  }

  void _handleRealtimeEmployeeUpdate(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final event = data['event'] ?? '';
    switch (event) {
      case 'employeeCreated':
        handleEmployeeCreated(data);
        break;
      case 'employeeUpdated':
        handleEmployeeUpdated(data);
        break;
      case 'employeeDeleted':
        handleEmployeeDeleted(data);
        break;
    }

    _triggerGentleRefresh(context);
  }

  void _handleRealtimeLeaveUpdate(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final event = data['event'] ?? '';
    switch (event) {
      case 'leaveRequestCreated':
        handleLeaveRequestCreated(data);
        break;
      case 'leaveRequestApproved':
        handleLeaveRequestApproved(data);
        break;
      case 'leaveRequestRejected':
        handleLeaveRequestRejected(data);
        break;
    }

    _triggerGentleRefresh(context);
  }

  void _handleRealtimeAnnouncementUpdate(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final event = data['event'] ?? '';
    switch (event) {
      case 'announcementCreated':
        handleAnnouncementCreated(data);
        break;
      case 'announcementUpdated':
        handleAnnouncementUpdated(data);
        break;
      case 'announcementDeleted':
        handleAnnouncementDeleted(data);
        break;
    }

    _triggerGentleRefresh(context);
  }

  void _triggerGentleRefresh(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      Connectivity()
          .checkConnectivity()
          .then((connectivity) async {
            final isOnline =
                connectivity.isNotEmpty &&
                connectivity.any((result) => result != ConnectivityResult.none);

            if (!isOnline) {
              return;
            }

            // if (_dashboardLoadedFromCache) {
            //   return;
            // }

            final doubleCheckConnectivity = await Connectivity()
                .checkConnectivity();
            final stillOnline =
                doubleCheckConnectivity.isNotEmpty &&
                doubleCheckConnectivity.any(
                  (result) => result != ConnectivityResult.none,
                );

            if (!stillOnline) {
              return;
            }

            fetchHRDashboardSummary(
              authProvider.token!,
              forceRefresh: false,
            ).catchError((e) {});
          })
          .catchError((e) {});
    }
  }

  void incrementPendingLeavesCount() {
    if (_dashboardData != null) {
      final currentCount = _dashboardData!['pendingLeaveApprovals'] ?? 0;
      _dashboardData!['pendingLeaveApprovals'] = currentCount + 1;
      notifyListeners();
    }
  }

  void decrementPendingLeavesCount() {
    if (_dashboardData != null) {
      final currentCount = _dashboardData!['pendingLeaveApprovals'] ?? 0;
      if (currentCount > 0) {
        _dashboardData!['pendingLeaveApprovals'] = currentCount - 1;
        notifyListeners();
      }
    }
  }
}

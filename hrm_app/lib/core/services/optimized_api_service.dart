import 'dart:convert';
import 'dart:io';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/core/services/cache_service.dart';

import 'package:http/http.dart' as http;

class OptimizedApiService {
  static Future<Map<String, dynamic>> getDashboardData(
    String token,
    String userRole, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCachedDashboardData(userRole);
      if (cachedData != null) {
        final needsRefresh = await CacheService.needsRefresh(
          'dashboard',
          userRole,
        );
        if (!needsRefresh) {
          return cachedData;
        }
      }
    }

    final endpoint = userRole == 'admin'
        ? '/api/admin/dashboard-summary'
        : userRole == 'hr'
        ? '/api/hr/dashboard-summary'
        : '/api/employee/dashboard-summary';

    final response = await _makeRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      endpoint: endpoint,
    );

    await CacheService.cacheDashboardData(response, userRole);
    await CacheService.setLastFetchTime('dashboard', userRole);

    return response;
  }

  static Future<Map<String, dynamic>> getProfileData(
    String token,
    String userRole, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedData = await CacheService.getCachedProfileData(userRole);
      if (cachedData != null) {
        final needsRefresh = await CacheService.needsRefresh(
          'profile',
          userRole,
        );
        if (!needsRefresh) {
          return cachedData is Map<String, dynamic>
              ? cachedData
              : Map<String, dynamic>.from(cachedData);
        }
      }
    }

    final endpoint = userRole == 'admin'
        ? '/api/user/profile'
        : userRole == 'hr'
        ? '/api/hr/profile'
        : '/api/employee/profile';

    final response = await _makeRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      endpoint: endpoint,
    );

    final responseData = response is Map<String, dynamic>
        ? response
        : Map<String, dynamic>.from(response);

    await CacheService.cacheProfileData(responseData, userRole);
    await CacheService.setLastFetchTime('profile', userRole);

    return responseData;
  }

  static Future<Map<String, dynamic>> getEmployeesData(
    String token,
    String userRole, {
    String? search,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1 && (search == null || search.isEmpty)) {
      final cachedData = await CacheService.getCachedEmployeesData(userRole);
      if (cachedData != null) {
        return cachedData;
      }
    }

    final endpoint = userRole == 'admin'
        ? '/api/admin/users/employee'
        : '/api/hr/employees';

    final queryParams = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );

    if (page == 1 && (search == null || search.isEmpty)) {
      await CacheService.cacheEmployeesData(response, userRole);
      await CacheService.setLastFetchTime('employees', userRole);
    }

    return response;
  }

  static Future<Map<String, dynamic>> getMessagesData(
    String token,
    String userRole, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1) {
      final cachedData = await CacheService.getCachedMessagesData(userRole);
      if (cachedData != null) {
        return cachedData;
      }
    }

    final endpoint = '/api/messages';

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '20',
    };

    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );

    if (page == 1) {
      await CacheService.cacheMessagesData(response, userRole);
      await CacheService.setLastFetchTime('messages', userRole);
    }

    return response;
  }

  static Future<Map<String, dynamic>> getAnnouncementsData(
    String token,
    String userRole, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1) {
      final cachedData = await CacheService.getCachedAnnouncementsData(
        userRole,
      );
      if (cachedData != null) {
        return cachedData;
      }
    }

    final endpoint = '/api/announcements';

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '10',
    };

    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );

    if (page == 1) {
      await CacheService.cacheAnnouncementsData(response, userRole);
      await CacheService.setLastFetchTime('announcements', userRole);
    }

    return response;
  }

  static Future<Map<String, dynamic>> getAnnouncementsForAudience(
    String audience,
    String token, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1) {
      final cachedData = await CacheService.getCachedAnnouncementsData(
        audience,
      );
      if (cachedData != null) {
        return cachedData;
      }
    }

    final endpoint = '/api/announcements/audience/$audience';

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '10',
    };

    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );

    if (page == 1) {
      await CacheService.cacheAnnouncementsData(response, audience);
      await CacheService.setLastFetchTime('announcements', audience);
    }

    return response;
  }

  static Future<Map<String, dynamic>> getEmployeeAnnouncements(
    String token, {
    int page = 1,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1) {
      final cachedData = await CacheService.getCachedAnnouncementsData(
        'employee',
      );
      if (cachedData != null) {
        return cachedData;
      }
    }

    final endpoint = '/api/employee/announcements';

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': '10',
    };

    final uri = _buildUri(endpoint).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );

    if (page == 1) {
      await CacheService.cacheAnnouncementsData(response, 'employee');
      await CacheService.setLastFetchTime('announcements', 'employee');
    }

    return response;
  }

  static Future<bool> needsRefresh(String dataType, String userRole) async {
    return await CacheService.needsRefresh(dataType, userRole);
  }

  static Future<void> clearCache(String dataType, String userRole) async {
    switch (dataType) {
      case 'dashboard':
        await CacheService.clearCache('dashboard_data_$userRole');
        break;
      case 'profile':
        await CacheService.clearCache('profile_data_$userRole');
        break;
      case 'employees':
        await CacheService.clearCache('employees_data_$userRole');
        break;
      case 'messages':
        await CacheService.clearCache('messages_data_$userRole');
        break;
      case 'announcements':
        await CacheService.clearCache('announcements_data_$userRole');
        break;
    }
  }

  static Future<void> clearAllCache() async {
    await CacheService.clearAllCache();
  }

  static Uri _buildUri(String endpoint) {
    return Uri.parse('${ApiConstants.baseUrl}$endpoint');
  }

  static Map<String, String> _jsonHeaders({String? token}) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<dynamic> _makeRequest(
    Future<http.Response> Function() request, {
    int expectedStatusCode = 200,
    String? endpoint,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await request().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const SocketException(
            'Request timeout - server not responding',
          );
        },
      );

      stopwatch.stop();

      if (response.statusCode != expectedStatusCode) {
        String message = 'API Error: Status Code ${response.statusCode}';
        try {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html') ||
              response.headers['content-type']?.contains('text/html') == true) {
            message = _extractTextFromHtml(response.body);
            if (message.isEmpty) {
              message = 'Server error occurred. Please try again later.';
            }
          } else {
            final responseData = json.decode(response.body);
            if (responseData is Map<String, dynamic> &&
                responseData.containsKey('message')) {
              message = responseData['message'] as String? ?? message;
            } else if (responseData is Map<String, dynamic> &&
                responseData.containsKey('error')) {
              message = responseData['error'] as String? ?? message;
            } else {
              message = response.body.isNotEmpty
                  ? (response.body.length > 100
                        ? '${response.body.substring(0, 100)}...'
                        : response.body)
                  : message;
            }
          }
        } catch (_) {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            message = _extractTextFromHtml(response.body);
            if (message.isEmpty) {
              message = 'Server error occurred. Please try again later.';
            }
          } else {
            message = response.body.isNotEmpty
                ? (response.body.length > 200
                      ? '${response.body.substring(0, 200)}...'
                      : response.body)
                : message;
          }
        }
        throw HttpException(message);
      }

      if (response.body.isEmpty) {
        return null;
      }

      try {
        final result = json.decode(response.body);
        return result;
      } on FormatException catch (e) {
        throw HttpException('Invalid JSON response from server: ${e.message}');
      }
    } on SocketException {
      stopwatch.stop();
      throw const SocketException('No Internet connection or server is down.');
    } on HttpException {
      stopwatch.stop();
      rethrow;
    } catch (e) {
      stopwatch.stop();
      if (e is FormatException) {
        throw const HttpException(
          'Received an invalid format from the server.',
        );
      }
      throw HttpException('An unexpected error occurred: ${e.toString()}');
    }
  }

  static String _extractTextFromHtml(String html) {
    String text = html.replaceAll(RegExp(r'<[^>]*>'), '');

    text = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®');

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.length > 200) {
      text = '${text.substring(0, 200)}...';
    }

    return text;
  }

  static Future<Map<String, dynamic>> submitEOD(
    String token,
    Map<String, dynamic> eodData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/eod/create'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(eodData),
      ),
      endpoint: '/api/eod/create',
      expectedStatusCode: 201,
    );
    return response;
  }

  static Future<Map<String, dynamic>> getTodayEOD(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/eod/today'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/eod/today',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEODEntries(
    String token, {
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = queryParams.isEmpty
        ? _buildUri('/api/eod/my-eods')
        : _buildUri('/api/eod/my-eods').replace(queryParameters: queryParams);

    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/eod/my-eods',
    );
    return response;
  }

  static Future<Map<String, dynamic>> updateEOD(
    String token,
    String eodId,
    Map<String, dynamic> eodData,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/eod/$eodId'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(eodData),
      ),
      endpoint: '/api/eod/$eodId',
    );
    return response;
  }

  static Future<Map<String, dynamic>> deleteEOD(
    String token,
    String eodId,
  ) async {
    final response = await _makeRequest(
      () => http.delete(
        _buildUri('/api/eod/$eodId'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/eod/$eodId',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEODStats(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/eod/stats'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/eod/stats',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEmployeeEODs(
    String token,
    String employeeId, {
    int page = 1,
    int limit = 20,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = _buildUri(
      '/api/eod/employee/$employeeId',
    ).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/eod/employee/$employeeId',
    );
    return response;
  }

  static Future<Map<String, dynamic>> applyForLeave(
    String token,
    Map<String, dynamic> leaveData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/leave/apply'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(leaveData),
      ),
      endpoint: '/api/leave/apply',
      expectedStatusCode: 201,
    );
    return response;
  }

  static Future<Map<String, dynamic>> getLeaveRequests(
    String token, {
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) queryParams['status'] = status;
    if (leaveType != null) queryParams['leaveType'] = leaveType;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = _buildUri(
      '/api/leave/my-requests',
    ).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/leave/my-requests',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getLeaveBalance(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/leave/balance'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/leave/balance',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getLeaveStatistics(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/leave/statistics'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/leave/statistics',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getBlackoutDates(
    String token, {
    int? year,
    int? month,
  }) async {
    final queryParams = <String, String>{};
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month.toString();

    final uri = _buildUri(
      '/api/leave/blackout-dates',
    ).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/leave/blackout-dates',
    );
    return response;
  }

  static Future<Map<String, dynamic>> cancelLeaveRequest(
    String token,
    String leaveRequestId,
    String? cancellationReason,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/leave/$leaveRequestId/cancel'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode({'cancellationReason': cancellationReason}),
      ),
      endpoint: '/api/leave/$leaveRequestId/cancel',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getHRContacts(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/hr-contacts'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/hr-contacts',
    );

    return response;
  }

  static Future<Map<String, dynamic>> getAdminContacts(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/admin-contacts'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/admin-contacts',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEmployeeContactsForMessaging(
    String token,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/employee-contacts'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/employee-contacts',
    );
    return response;
  }

  static Future<Map<String, dynamic>> sendMessageToHR(
    String token,
    Map<String, dynamic> messageData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/employee/messages/hr'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(messageData),
      ),
      expectedStatusCode: 201,
      endpoint: '/api/employee/messages/hr',
    );

    return response;
  }

  static Future<Map<String, dynamic>> sendMessageToAdmin(
    String token,
    Map<String, dynamic> messageData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/employee/messages/admin'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(messageData),
      ),
      expectedStatusCode: 201,
      endpoint: '/api/employee/messages/admin',
    );
    return response;
  }

  static Future<Map<String, dynamic>> sendMessageToEmployee(
    String token,
    Map<String, dynamic> messageData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/employee/messages/employee'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(messageData),
      ),
      expectedStatusCode: 201,
      endpoint: '/api/employee/messages/employee',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEmployeeMessages(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/messages'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/messages',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getEmployeeConversation(
    String token,
    String userId,
    String userType,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/conversation/$userId/$userType'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/conversation/$userId/$userType',
    );
    return response;
  }

  static Future<Map<String, dynamic>> markMessageAsRead(
    String token,
    String messageId,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/employee/messages/$messageId/read'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/messages/$messageId/read',
    );
    return response;
  }

  static Future<Map<String, dynamic>> markConversationAsSeen(
    String token,
    String userId,
    String userType,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/employee/conversation/$userId/$userType/seen'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/conversation/$userId/$userType/seen',
    );
    return response;
  }

  static Future<Map<String, dynamic>> checkMessagingPermission(
    String token,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/messaging-permissions/check'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/messaging-permissions/check',
    );
    return response;
  }

  static Future<Map<String, dynamic>> requestMessagingPermission(
    String token, {
    String? adminId,
  }) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/messaging-permissions/request'),
        headers: _jsonHeaders(token: token),
        body: adminId != null ? jsonEncode({'adminId': adminId}) : null,
      ),
      endpoint: '/api/messaging-permissions/request',
    );
    return response;
  }

  static Future<Map<String, dynamic>> grantMessagingPermission(
    String token,
    String employeeId, {
    bool canChat = true,
  }) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/messaging-permissions/grant'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode({'employeeId': employeeId, 'canChat': canChat}),
      ),
      endpoint: '/api/messaging-permissions/grant',
    );
    return response;
  }

  // Payslip methods
  static Future<List<dynamic>> getPayslips(
    String token, {
    int page = 1,
    int limit = 20,
    int? year,
    String? month,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (year != null) queryParams['year'] = year.toString();
    if (month != null) queryParams['month'] = month;

    final uri = Uri(queryParameters: queryParams);
    final endpoint = '/api/employee/payslips?${uri.query}';

    final response = await _makeRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      endpoint: '/api/employee/payslips',
    );
    return response['payslips'] ?? [];
  }

  static Future<Map<String, dynamic>> getSalaryBreakdownPreview(
    String token, {
    required String month,
    required int year,
  }) async {
    final Map<String, dynamic> queryParams = {
      'month': month,
      'year': year.toString(),
    };

    final uri = Uri(queryParameters: queryParams);
    final endpoint = '/api/employee/payslips/preview?${uri.query}';

    final response = await _makeRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      endpoint: '/api/employee/payslips/preview',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getCurrentSalary(String token) async {
    // Current salary is usually part of the employee profile or latest payslip
    // This is a placeholder as backend endpoint might vary
    // We try to fetch profile which usually contains salary info
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/employee/profile'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/employee/profile',
    );
    return response;
  }

  static Future<List<dynamic>> getPayslipRequests(String token) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/payslip-requests/employee'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/payslip-requests/employee',
    );
    return response['requests'] ?? [];
  }

  static Future<Map<String, dynamic>> revokeMessagingPermission(
    String token,
    String employeeId,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/messaging-permissions/revoke/$employeeId'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/messaging-permissions/revoke/$employeeId',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getMessagingPermissionRequests(
    String token,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/messaging-permissions/requests'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/messaging-permissions/requests',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getActiveMessagingPermissions(
    String token,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/messaging-permissions/active'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/messaging-permissions/active',
    );
    return response;
  }

  static Future<Map<String, dynamic>> updateEmployeeProfile(
    String token,
    Map<String, dynamic> profileData,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/employee/profile'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(profileData),
      ),
      endpoint: '/api/employee/profile',
    );
    return response;
  }

  static Future<Map<String, dynamic>> uploadEmployeeProfileImage(
    String token,
    File imageFile,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _buildUri('/api/employee/profile/image'),
    );

    request.headers.addAll(_jsonHeaders(token: token));
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw HttpException('Failed to upload image: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getEmployeeLeaveData(
    String token,
    String employeeId,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/hr/employees/$employeeId/leave-data'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/hr/employees/$employeeId/leave-data',
    );

    return response;
  }

  static Future<Map<String, dynamic>> updateEmployeeLeaveData(
    String token,
    String employeeId,
    Map<String, dynamic> leaveData,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/hr/employees/$employeeId/leave-data'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(leaveData),
      ),
      endpoint: '/api/hr/employees/$employeeId/leave-data',
    );
    return response;
  }

  static Future<Map<String, dynamic>> submitPayslipRequest(
    String token,
    Map<String, dynamic> requestData,
  ) async {
    final response = await _makeRequest(
      () => http.post(
        _buildUri('/api/payslip-requests/submit'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(requestData),
      ),
      expectedStatusCode: 201,
      endpoint: '/api/payslip-requests/submit',
    );

    return response;
  }

  static Future<Map<String, dynamic>> getEmployeePayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;

    final uri = _buildUri(
      '/api/payslip-requests/employee',
    ).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/payslip-requests/employee',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getHRPayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;

    final uri = _buildUri(
      '/api/payslip-requests/hr',
    ).replace(queryParameters: queryParams);
    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/payslip-requests/hr',
    );
    return response;
  }

  static Future<Map<String, dynamic>> updatePayslipRequestStatus(
    String token,
    String requestId,
    Map<String, dynamic> statusData,
  ) async {
    final response = await _makeRequest(
      () => http.put(
        _buildUri('/api/payslip-requests/$requestId/status'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(statusData),
      ),
      endpoint: '/api/payslip-requests/$requestId/status',
    );

    return response;
  }

  static Future<Map<String, dynamic>> getPayslipRequestStats(
    String token,
  ) async {
    final response = await _makeRequest(
      () => http.get(
        _buildUri('/api/payslip-requests/hr/stats'),
        headers: _jsonHeaders(token: token),
      ),
      endpoint: '/api/payslip-requests/hr/stats',
    );
    return response;
  }

  static Future<Map<String, dynamic>> getPayslipApprovalHistory(
    String token, {
    int page = 1,
    int limit = 20,
    String? employeeName,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (employeeName != null) queryParams['employeeName'] = employeeName;

    final uri = _buildUri(
      '/api/payslip-requests/hr/history',
    ).replace(queryParameters: queryParams);

    final response = await _makeRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
      endpoint: '/api/payslip-requests/hr/history',
    );

    return response;
  }

  static Future<Map<String, dynamic>> processPayslipWithBasePay(
    String token,
    String requestId,
    Map<String, dynamic> payrollData,
  ) async {
    if (requestId.isEmpty || requestId.trim().isEmpty) {
      throw const HttpException('Invalid payslip request ID');
    }

    final cleanRequestId = requestId.trim();

    if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(cleanRequestId)) {
      throw const HttpException('Invalid payslip request ID format');
    }

    final endpoint = '/api/payslip-requests/$cleanRequestId/process';

    try {
      final response = await _makeRequest(
        () => http.post(
          _buildUri(endpoint),
          headers: _jsonHeaders(token: token),
          body: jsonEncode(payrollData),
        ),
        expectedStatusCode: 200,
        endpoint: endpoint,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<int>> previewPayslip(
    String token,
    String requestId,
    Map<String, dynamic> payrollData,
  ) async {
    final endpoint = '/api/payslip-requests/$requestId/preview';
    final uri = _buildUri(endpoint);

    final response = await http.post(
      uri,
      headers: _jsonHeaders(token: token),
      body: jsonEncode(payrollData),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw HttpException('Failed to generate preview: ${response.statusCode}');
    }
  }
}

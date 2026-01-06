import 'dart:convert';
import 'dart:io';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:http/http.dart' as http;

Uri _buildUri(String endpoint) {
  return Uri.parse('${ApiConstants.baseUrl}$endpoint');
}

class ApiService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = _buildUri('/api/auth/login');
    final response = await _handleRequest(
      () => http.post(
        uri,
        headers: _jsonHeaders(),
        body: json.encode({'email': email, 'password': password}),
      ),
    );
    return _validateMapResponse(response, 'login API');
  }

  Future<void> logout(String token) async {
    await _handleRequest(
      () => http.post(
        _buildUri('/api/auth/logout'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getAdminDashboardSummary(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/admin/dashboard-summary'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return _validateMapResponse(response, 'dashboard API');
  }

  Future<List<dynamic>> getUsersByRole(String role, String token) async {
    final endpoint = '/api/admin/users/$role';
    final response = await _handleRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
    );
    return _validateListResponse(response, 'users API');
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
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };

    if (subOrganisation != null && subOrganisation.isNotEmpty) {
      body['subOrganisation'] = subOrganisation;
    }
    if (employeeId != null && employeeId.isNotEmpty) {
      body['employeeId'] = employeeId;
    }
    if (jobTitle != null && jobTitle.isNotEmpty) {
      body['jobTitle'] = jobTitle;
    }

    await _handleRequest(
      () => http.post(
        _buildUri('/api/admin/create-user'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<void> updateUser(
    String userId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final endpoint = '/api/admin/users/$userId';
    await _handleRequest(
      () => http.put(
        _buildUri(endpoint),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      isVoid: true,
    );
  }

  Future<void> deleteUser(String userId, String token) async {
    final endpoint = '/api/admin/users/$userId';
    await _handleRequest(
      () =>
          http.delete(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getHRDashboardSummary(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/hr/dashboard-summary'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRProfile(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/hr/profile'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> updateHRProfile(Map<String, dynamic> data, String token) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/hr/profile'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getHREmployees(
    String token, {
    String? search,
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(
      '/api/hr/employees',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> createHREmployee(
    String name,
    String email,
    String password,
    String subOrganisation,
    String employeeId,
    String token, {
    String? jobTitle,
    String? phone,
  }) async {
    final Map<String, dynamic> body = {
      'name': name,
      'email': email,
      'password': password,
      'subOrganisation': subOrganisation,
      'employeeId': employeeId,
    };

    if (jobTitle != null && jobTitle.isNotEmpty) {
      body['jobTitle'] = jobTitle;
    }
    if (phone != null && phone.isNotEmpty) {
      body['phone'] = phone;
    }

    await _handleRequest(
      () => http.post(
        _buildUri('/api/hr/employees'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<void> updateHREmployee(
    String employeeId,
    Map<String, dynamic> data,
    String token,
  ) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/hr/employees/$employeeId'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      isVoid: true,
    );
  }

  Future<void> deleteHREmployee(String employeeId, String token) async {
    await _handleRequest(
      () => http.delete(
        _buildUri('/api/hr/employees/$employeeId'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getHREmployeesForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(
      '/api/hr/employees-for-messaging',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRAdminsForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(
      '/api/hr/admins-for-messaging',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> sendHRMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    final body = {
      'recipientId': employeeId,
      'subject': subject,
      'content': content,
      'priority': priority,
    };

    await _handleRequest(
      () => http.post(
        _buildUri('/api/hr/send-to-employee'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<void> sendHRMessageToAdmin(
    String adminId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    final body = {
      'recipientId': adminId,
      'subject': subject,
      'content': content,
      'priority': priority,
    };

    await _handleRequest(
      () => http.post(
        _buildUri('/api/hr/send-to-admin'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getHRMessages(
    String token, {
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};

    final uri = _buildUri(
      '/api/hr/messages',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRConversation(
    String userId,
    String userType,
    String token,
  ) async {
    final uri = _buildUri('/api/hr/conversation/$userId/$userType');
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> markHRMessageAsRead(String messageId, String token) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/hr/messages/$messageId/read'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<void> sendAdminMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    final body = {
      'recipientId': employeeId,
      'subject': subject,
      'content': content,
      'priority': priority,
    };

    await _handleRequest(
      () => http.post(
        _buildUri('/api/messages/send-to-employee'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<void> sendAdminMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    final body = {
      'recipientId': hrId,
      'subject': subject,
      'content': content,
      'priority': priority,
    };

    await _handleRequest(
      () => http.post(
        _buildUri('/api/messages/send-to-hr'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getAdminConversation(
    String userId,
    String userType,
    String token,
  ) async {
    final uri = _buildUri('/api/messages/conversation/$userId/$userType');
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> markHRConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/hr/mark-conversation-seen/$userId/$userType'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<void> createHRAnnouncement(
    String title,
    String message,
    String token, {
    String audience = 'employees',
    String priority = 'normal',
  }) async {
    final body = {
      'title': title,
      'message': message,
      'audience': audience,
      'priority': priority,
    };

    await _handleRequest(
      () => http.post(
        _buildUri('/api/hr/announcements'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      expectedStatusCode: 201,
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getHRAnnouncements(
    String token, {
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};

    final uri = _buildUri(
      '/api/hr/announcements',
    ).replace(queryParameters: queryParams);
    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/user/profile'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> data, String token) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/user/profile'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      isVoid: true,
    );
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
    String token,
  ) async {
    final body = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
    await _handleRequest(
      () => http.put(
        _buildUri('/api/user/password'),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
      isVoid: true,
    );
  }

  Future<List<dynamic>> getPayrollsForEmployee(
    String employeeId,
    String token,
  ) async {
    final endpoint = '/api/payroll/employee/$employeeId';
    final response = await _handleRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
    );
    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPayroll(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/payroll'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      expectedStatusCode: 201,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePayroll(
    String payrollId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final endpoint = '/api/payroll/$payrollId';
    final response = await _handleRequest(
      () => http.put(
        _buildUri(endpoint),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deletePayroll(String payrollId, String token) async {
    final endpoint = '/api/payroll/$payrollId';
    await _handleRequest(
      () =>
          http.delete(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> createAnnouncement(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/announcements'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      expectedStatusCode: 201,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncements(
    String token, {
    int page = 1,
    int limit = 10,
    String? audience,
    String? priority,
    bool isActive = true,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'isActive': isActive.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (audience != null) queryParams['audience'] = audience;
    if (priority != null) queryParams['priority'] = priority;

    final uri = _buildUri(
      '/api/announcements',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncementsForAudience(
    String audience,
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = _buildUri(
      '/api/announcements/audience/$audience',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnouncementById(
    String announcementId,
    String token,
  ) async {
    final endpoint = '/api/announcements/$announcementId';
    final response = await _handleRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final endpoint = '/api/announcements/$announcementId';
    final response = await _handleRequest(
      () => http.put(
        _buildUri(endpoint),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteAnnouncement(String announcementId, String token) async {
    final endpoint = '/api/announcements/$announcementId';
    await _handleRequest(
      () =>
          http.delete(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> sendMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
  }) async {
    final data = {
      'employeeId': employeeId,
      'subject': subject,
      'content': content,
      'priority': priority,
      if (attachments != null) 'attachments': attachments,
      if (scheduledFor != null) 'scheduledFor': scheduledFor.toIso8601String(),
    };

    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/messages/send-to-employee'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      expectedStatusCode: 201,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
  }) async {
    final data = {
      'hrId': hrId,
      'subject': subject,
      'content': content,
      'priority': priority,
      if (attachments != null) 'attachments': attachments,
      if (scheduledFor != null) 'scheduledFor': scheduledFor.toIso8601String(),
    };

    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/messages/send-to-hr'),
        headers: _jsonHeaders(token: token),
        body: json.encode(data),
      ),
      expectedStatusCode: 201,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMessages(
    String token, {
    int page = 1,
    int limit = 20,
    String? messageType,
    String? status,
    String? priority,
    bool? isRead,
    bool isArchived = false,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'isArchived': isArchived.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (messageType != null) queryParams['messageType'] = messageType;
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (isRead != null) queryParams['isRead'] = isRead.toString();

    final uri = _buildUri(
      '/api/messages',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversation(
    String userId,
    String userType,
    String token, {
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = _buildUri(
      '/api/messages/conversation/$userId/$userType',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> markMessageAsRead(String messageId, String token) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/messages/$messageId/read'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<void> markMultipleMessagesAsRead(
    List<String> messageIds,
    String token,
  ) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/messages/mark-multiple-read'),
        headers: _jsonHeaders(token: token),
        body: json.encode({'messageIds': messageIds}),
      ),
      isVoid: true,
    );
  }

  Future<void> archiveMessage(String messageId, String token) async {
    await _handleRequest(
      () => http.put(
        _buildUri('/api/messages/$messageId/archive'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<void> deleteMessage(String messageId, String token) async {
    await _handleRequest(
      () => http.delete(
        _buildUri('/api/messages/$messageId'),
        headers: _jsonHeaders(token: token),
      ),
      isVoid: true,
    );
  }

  Future<Map<String, dynamic>> getMessageStats(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/messages/stats'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeesForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(
      '/api/messages/employees',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = _buildUri(
      '/api/messages/hr-users',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    String? leaveType,
    String? employeeId,
    String? startDate,
    String? endDate,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };

    if (status != null) queryParams['status'] = status;
    if (leaveType != null) queryParams['leaveType'] = leaveType;
    if (employeeId != null) queryParams['employeeId'] = employeeId;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = _buildUri(
      '/api/leave-requests',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestStats(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/leave-requests/stats'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveCalendar(
    String token, {
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = _buildUri(
      '/api/leave-requests/calendar',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestsByEmployee(
    String employeeId,
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final uri = _buildUri(
      '/api/leave-requests/employee/$employeeId',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestById(
    String leaveRequestId,
    String token,
  ) async {
    final endpoint = '/api/leave-requests/$leaveRequestId';
    final response = await _handleRequest(
      () => http.get(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLeaveRequestStatus(
    String leaveRequestId,
    String status,
    String token, {
    String? adminComments,
  }) async {
    final endpoint = '/api/leave-requests/$leaveRequestId/status';
    final body = {
      'status': status,
      if (adminComments != null) 'adminComments': adminComments,
    };

    final response = await _handleRequest(
      () => http.put(
        _buildUri(endpoint),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkUpdateLeaveRequests(
    List<String> leaveRequestIds,
    String status,
    String token, {
    String? adminComments,
  }) async {
    final endpoint = '/api/leave-requests/bulk-update';
    final body = {
      'leaveRequestIds': leaveRequestIds,
      'status': status,
      if (adminComments != null) 'adminComments': adminComments,
    };

    final response = await _handleRequest(
      () => http.put(
        _buildUri(endpoint),
        headers: _jsonHeaders(token: token),
        body: json.encode(body),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteLeaveRequest(String leaveRequestId, String token) async {
    final endpoint = '/api/leave-requests/$leaveRequestId';
    await _handleRequest(
      () =>
          http.delete(_buildUri(endpoint), headers: _jsonHeaders(token: token)),
      isVoid: true,
    );
  }

  Map<String, String> _jsonHeaders({String? token}) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _validateMapResponse(dynamic response, String apiName) {
    if (response == null) {
      throw HttpException('Empty response from $apiName');
    }
    if (response is! Map<String, dynamic>) {
      throw HttpException('Invalid response format from $apiName');
    }
    return response;
  }

  List<dynamic> _validateListResponse(dynamic response, String apiName) {
    if (response == null) {
      throw HttpException('Empty response from $apiName');
    }
    if (response is! List<dynamic>) {
      throw HttpException('Invalid response format from $apiName');
    }
    return response;
  }

  Future<Map<String, dynamic>> punchIn(String token) async {
    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/attendance/punch-in'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> punchOut(String token) async {
    final response = await _handleRequest(
      () => http.post(
        _buildUri('/api/attendance/punch-out'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceStatus(String token) async {
    final response = await _handleRequest(
      () => http.get(
        _buildUri('/api/attendance/status'),
        headers: _jsonHeaders(token: token),
      ),
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceHistory(
    String token, {
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    final uri = _buildUri(
      '/api/attendance/history',
    ).replace(queryParameters: queryParams);

    final response = await _handleRequest(
      () => http.get(uri, headers: _jsonHeaders(token: token)),
    );
    return response as Map<String, dynamic>;
  }

  Future<dynamic> _handleRequest(
    Future<http.Response> Function() request, {
    int expectedStatusCode = 200,
    bool isVoid = false,
  }) async {
    try {
      final response = await request().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const SocketException(
            'Request timeout - server not responding',
          );
        },
      );

      if (response.statusCode != expectedStatusCode) {
        String message = 'API Error: Status Code ${response.statusCode}';
        try {
          final responseData = json.decode(response.body);
          if (responseData is Map<String, dynamic> &&
              responseData.containsKey('message')) {
            message = responseData['message'] as String? ?? response.body;
          } else {
            message = response.body.isNotEmpty
                ? (response.body.length > 100
                      ? '${response.body.substring(0, 100)}...'
                      : response.body)
                : 'API Error: Status Code ${response.statusCode}';
          }
        } catch (_) {
          message = response.body.isNotEmpty
              ? (response.body.length > 100
                    ? '${response.body.substring(0, 100)}...'
                    : response.body)
              : 'API Error: Status Code ${response.statusCode}';
        }
        throw HttpException(message);
      }

      if (isVoid) {
        return null;
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
      throw const SocketException('No Internet connection or server is down.');
    } on HttpException {
      rethrow;
    } catch (e) {
      if (e is FormatException) {
        throw const HttpException(
          'Received an invalid format from the server.',
        );
      }
      throw HttpException('An unexpected error occurred: ${e.toString()}');
    }
  }
}

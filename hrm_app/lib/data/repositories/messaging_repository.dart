import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/services/http_service.dart';

class MessagingRepository {
  final HttpService _httpService;

  MessagingRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> getConversations(
    String token, {
    String role = 'employee',
  }) async {
    final endpoint = role == 'hr'
        ? '/api/hr/messages'
        : '/api/employee/messages';

    final response = await _httpService.get(
      endpoint,
      token: token,
      contextName: 'Get Messages',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminConversation(
    String userId,
    String userType,
    String token, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'admin_${userId}_${userType.toLowerCase()}';

    if (!forceRefresh) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        cacheKey,
      );
      if (cached != null) {
        return {'conversation': cached, 'messages': cached};
      }
    }

    final response = await _httpService.get(
      '/api/messages/conversation/$userId/$userType',
      token: token,
      contextName: 'Get Admin Conversation',
    );

    List<dynamic> messages = [];
    if (response['conversation'] is List) {
      messages = response['conversation'];
    } else if (response['messages'] is List) {
      messages = response['messages'];
    }

    await HiveCacheService.cacheConversationMessages(cacheKey, messages);

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHREmployeesForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final response = await _httpService.get(
      '/api/hr/employees-for-messaging',
      token: token,
      queryParams: queryParams,
      contextName: 'HR Employees for Messaging',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRAdminsForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final response = await _httpService.get(
      '/api/hr/admins-for-messaging',
      token: token,
      queryParams: queryParams,
      contextName: 'HR Admins for Messaging',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeesForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final response = await _httpService.get(
      '/api/messages/employees',
      token: token,
      queryParams: queryParams,
      contextName: 'Employees for Messaging',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRForMessaging(
    String token, {
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final response = await _httpService.get(
      '/api/messages/hr-users',
      token: token,
      queryParams: queryParams,
      contextName: 'HR for Messaging',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> markConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    await _httpService.put(
      '/api/employee/conversation/$userId/$userType/seen',
      token: token,
      isVoid: true,
      contextName: 'Mark Conversation Seen',
    );
  }

  Future<Map<String, dynamic>> checkMessagingPermission(String token) async {
    final response = await _httpService.get(
      '/api/messaging-permissions/check',
      token: token,
      contextName: 'Check Msg Permission',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> requestMessagingPermission(
    String token, {
    String? adminId,
  }) async {
    final body = adminId != null ? {'adminId': adminId} : {};
    await _httpService.post(
      '/api/messaging-permissions/request',
      token: token,
      body: body,
      contextName: 'Request Msg Permission',
    );
  }

  Future<dynamic> _performSendMessage({
    required String endpoint,
    required String recipientId,
    required String recipientKey,
    required String subject,
    required String content,
    required String token,
    String priority = 'normal',
    String? contextName,
    Map<String, dynamic>? extraBody,
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
    int expectedStatusCode = 201,
    bool isVoid = true,
  }) async {
    final body = <String, dynamic>{
      recipientKey: recipientId,
      'subject': subject,
      'content': content,
      'priority': priority,
      ...?extraBody,
    };

    if (attachments != null) body['attachments'] = attachments;
    if (scheduledFor != null) {
      body['scheduledFor'] = scheduledFor.toIso8601String();
    }

    return await _httpService.post(
      endpoint,
      token: token,
      body: body,
      expectedStatusCode: expectedStatusCode,
      isVoid: isVoid,
      contextName: contextName ?? 'Send Message',
    );
  }

  Future<void> sendHRMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/hr/send-to-employee',
      recipientId: employeeId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      contextName: 'Send HR Msg to Employee',
    );
  }

  Future<void> sendHRMessageToAdmin(
    String adminId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/hr/send-to-admin',
      recipientId: adminId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      contextName: 'Send HR Msg to Admin',
    );
  }

  Future<void> sendAdminMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/messages/send-to-employee',
      recipientId: employeeId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      contextName: 'Send Admin Msg to Employee',
    );
  }

  Future<void> sendAdminMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/messages/send-to-hr',
      recipientId: hrId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      contextName: 'Send Admin Msg to HR',
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
    final response = await _performSendMessage(
      endpoint: '/api/messages/send-to-employee',
      recipientId: employeeId,
      recipientKey: 'employeeId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      attachments: attachments,
      scheduledFor: scheduledFor,
      contextName: 'Send Msg to Employee',
      isVoid: false,
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
    final response = await _performSendMessage(
      endpoint: '/api/messages/send-to-hr',
      recipientId: hrId,
      recipientKey: 'hrId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      attachments: attachments,
      scheduledFor: scheduledFor,
      contextName: 'Send Msg to HR',
      isVoid: false,
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
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'isArchived': isArchived,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (messageType != null) queryParams['messageType'] = messageType;
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (isRead != null) queryParams['isRead'] = isRead;

    final response = await _httpService.get(
      '/api/messages',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Messages',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRMessages(
    String token, {
    int page = 1,
  }) async {
    final response = await _httpService.get(
      '/api/hr/messages',
      token: token,
      queryParams: {'page': page},
      contextName: 'Get HR Messages',
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
    final response = await _httpService.get(
      '/api/messages/conversation/$userId/$userType',
      token: token,
      queryParams: {'page': page, 'limit': limit},
      contextName: 'Get Conversation',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHRConversation(
    String userId,
    String userType,
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/hr/conversation/$userId/$userType',
      token: token,
      contextName: 'Get HR Conversation',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeeConversation(
    String userId,
    String userType,
    String token, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _httpService.get(
      '/api/employee/conversation/$userId/$userType',
      token: token,
      queryParams: {'page': page, 'limit': limit},
      contextName: 'Get Employee Conversation',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> markMessageAsRead(String messageId, String token) async {
    await _httpService.put(
      '/api/messages/$messageId/read',
      token: token,
      isVoid: true,
      contextName: 'Mark Msg Read',
    );
  }

  Future<void> markHRMessageAsRead(String messageId, String token) async {
    await _httpService.put(
      '/api/hr/messages/$messageId/read',
      token: token,
      isVoid: true,
      contextName: 'Mark HR Msg Read',
    );
  }

  Future<void> markHRConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    await _httpService.put(
      '/api/hr/mark-conversation-seen/$userId/$userType',
      token: token,
      isVoid: true,
      contextName: 'Mark Conversation Seen',
    );
  }

  Future<void> markAdminConversationAsSeen(
    String userId,
    String userType,
    String token,
  ) async {
    await _httpService.put(
      '/api/admin/conversation/$userId/$userType/seen',
      token: token,
      isVoid: true,
      contextName: 'Mark Admin Conv Seen',
    );
  }

  Future<void> markMultipleMessagesAsRead(
    List<String> messageIds,
    String token,
  ) async {
    await _httpService.put(
      '/api/messages/mark-multiple-read',
      token: token,
      body: {'messageIds': messageIds},
      isVoid: true,
      contextName: 'Mark Multiple Read',
    );
  }

  Future<void> archiveMessage(String messageId, String token) async {
    await _httpService.put(
      '/api/messages/$messageId/archive',
      token: token,
      isVoid: true,
      contextName: 'Archive Message',
    );
  }

  Future<void> deleteMessage(String messageId, String token) async {
    await _httpService.delete(
      '/api/messages/$messageId',
      token: token,
      isVoid: true,
      contextName: 'Delete Message',
    );
  }

  Future<Map<String, dynamic>> getMessageStats(String token) async {
    final response = await _httpService.get(
      '/api/messages/stats',
      token: token,
      contextName: 'Message Stats',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeeHRContacts(String token) async {
    final response = await _httpService.get(
      '/api/employee/hr-contacts',
      token: token,
      contextName: 'Employee HR Contacts',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeeAdminContacts(String token) async {
    final response = await _httpService.get(
      '/api/employee/admin-contacts',
      token: token,
      contextName: 'Employee Admin Contacts',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeePeerContacts(String token) async {
    final response = await _httpService.get(
      '/api/employee/employee-contacts',
      token: token,
      contextName: 'Employee Peer Contacts',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> sendEmployeeMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/employee/messages/hr',
      recipientId: hrId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      extraBody: {'recipientType': 'hr'},
      contextName: 'Employee Msg to HR',
    );
  }

  Future<void> sendEmployeeMessageToAdmin(
    String adminId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/employee/messages/admin',
      recipientId: adminId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      extraBody: {'recipientType': 'admin'},
      contextName: 'Employee Msg to Admin',
    );
  }

  Future<void> sendEmployeeMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
  }) async {
    await _performSendMessage(
      endpoint: '/api/employee/messages/employee',
      recipientId: employeeId,
      recipientKey: 'recipientId',
      subject: subject,
      content: content,
      token: token,
      priority: priority,
      extraBody: {'recipientType': 'employee'},
      contextName: 'Employee Msg to Peer',
    );
  }

  Future<Map<String, dynamic>> getEmployeeMessages(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    final response = await _httpService.get(
      '/api/employee/messages',
      token: token,
      queryParams: queryParams,
      contextName: 'Employee Messages',
    );
    return response as Map<String, dynamic>;
  }
}

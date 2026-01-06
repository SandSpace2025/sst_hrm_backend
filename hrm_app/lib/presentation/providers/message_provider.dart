import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/services/api_service.dart';
import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/services/notification_service.dart';
import 'package:hrm_app/data/models/message_model.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class MessageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<MessageModel> _messages = [];
  List<MessageModel> _conversationMessages = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _hrUsers = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String? _selectedMessageType;
  String? _selectedStatus;
  String? _selectedPriority;
  bool _showArchived = false;
  Map<String, dynamic>? _stats;

  String? _currentConversationUserId;

  List<MessageModel> get messages => _messages;
  List<MessageModel> get conversationMessages => _conversationMessages;
  List<Map<String, dynamic>> get employees => _employees;
  List<Map<String, dynamic>> get hrUsers => _hrUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  String? get selectedMessageType => _selectedMessageType;
  String? get selectedStatus => _selectedStatus;
  String? get selectedPriority => _selectedPriority;
  bool get showArchived => _showArchived;
  Map<String, dynamic>? get stats => _stats;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setFilters({
    String? messageType,
    String? status,
    String? priority,
    bool? showArchived,
  }) {
    _selectedMessageType = messageType;
    _selectedStatus = status;
    _selectedPriority = priority;
    _showArchived = showArchived ?? false;
    notifyListeners();
  }

  void clearFilters() {
    _selectedMessageType = null;
    _selectedStatus = null;
    _selectedPriority = null;
    _showArchived = false;
    notifyListeners();
  }

  String _getUserRole() {
    try {
      final navigatorKey = NotificationService.globalNavigatorKey;
      if (navigatorKey?.currentContext != null) {
        final authProvider = Provider.of<AuthProvider>(
          navigatorKey!.currentContext!,
          listen: false,
        );
        final role = authProvider.role?.toLowerCase() ?? 'employee';
        return role;
      }
    } catch (e) {}

    return 'employee';
  }

  Future<bool> _isOnline() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      return conn.isNotEmpty &&
          conn.any((result) => result != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<void> loadMessages(
    String token, {
    bool refresh = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading && !refresh && !forceRefresh) return;

    if (refresh || forceRefresh) {
      _currentPage = 1;
      _messages.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData && !refresh && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final role = _getUserRole();

      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedMessages(role);
        if (cached != null && cached.isNotEmpty) {
          _messages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _isLoading = false;
          _error = null;
          notifyListeners();

          return;
        }
      }

      final online = await _isOnline();

      if (!online) {
        final cached = await HiveCacheService.getCachedMessages(role);
        if (cached != null && cached.isNotEmpty) {
          _messages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _messages = [];
          _error = 'No internet connection';
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        final response = await _apiService.getMessages(
          token,
          page: _currentPage,
          limit: 20,
          messageType: _selectedMessageType,
          status: _selectedStatus,
          priority: _selectedPriority,
          isArchived: _showArchived,
        );

        final List<dynamic> messagesData = response['messages'] ?? [];
        final List<MessageModel> newMessages = messagesData
            .map((data) => MessageModel.fromJson(data))
            .toList();

        if (refresh || forceRefresh) {
          _messages = newMessages;
        } else {
          _messages.addAll(newMessages);
        }

        await HiveCacheService.cacheMessages(
          role,
          _messages.map((m) => m.toJson()).toList(),
        );

        final pagination = response['pagination'];
        _hasMoreData = _currentPage < (pagination['totalPages'] ?? 1);
        _currentPage++;

        _error = null;
      } on SocketException {
        final cached = await HiveCacheService.getCachedMessages(role);
        if (cached != null && cached.isNotEmpty) {
          _messages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _error = 'No internet connection';
          _messages = [];
        }
      } catch (e) {
        final cached = await HiveCacheService.getCachedMessages(role);
        if (cached != null && cached.isNotEmpty) {
          _messages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _error = e.toString();
          _messages = [];
        }
      }
    } catch (e) {
      final role = _getUserRole();
      final cached = await HiveCacheService.getCachedMessages(role);
      if (cached != null && cached.isNotEmpty) {
        _messages = cached.map((data) => MessageModel.fromJson(data)).toList();
        _error = null;
      } else {
        _error = e.toString();
        _messages = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadConversation(
    String userId,
    String userType,
    String token, {
    bool refresh = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading && !refresh && !forceRefresh) return;

    _currentConversationUserId = userId;

    if (refresh || forceRefresh) {
      _currentPage = 1;
      _conversationMessages.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData && !refresh && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final currentUserRole = _getUserRole();
    final conversationKey =
        '${currentUserRole}_${userId}_${userType.toLowerCase()}';

    try {
      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationKey,
        );
        if (cached != null) {
          _conversationMessages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _isLoading = false;
          _error = null;
          notifyListeners();

          return;
        }
      }

      final online = await _isOnline();

      if (!online) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationKey,
        );
        if (cached != null) {
          _conversationMessages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _conversationMessages = [];
          _error = 'No internet connection';
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      try {
        final response = await _apiService.getConversation(
          userId,
          userType,
          token,
          page: _currentPage,
          limit: 50,
        );

        final List<dynamic> messagesData = response['messages'] ?? [];
        final List<MessageModel> newMessages = messagesData
            .map((data) => MessageModel.fromJson(data))
            .toList();

        if (refresh || forceRefresh) {
          _conversationMessages = newMessages;
        } else {
          _conversationMessages.addAll(newMessages);
        }

        await HiveCacheService.cacheConversationMessages(
          conversationKey,
          _conversationMessages.map((m) => m.toJson()).toList(),
        );

        final pagination = response['pagination'];
        _hasMoreData = _currentPage < (pagination['totalPages'] ?? 1);
        _currentPage++;

        _error = null;
      } on SocketException {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationKey,
        );
        if (cached != null) {
          _conversationMessages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _error = 'No internet connection';
          _conversationMessages = [];
        }
      } catch (e) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationKey,
        );
        if (cached != null) {
          _conversationMessages = cached
              .map((data) => MessageModel.fromJson(data))
              .toList();
          _error = null;
        } else {
          _error = e.toString();
          _conversationMessages = [];
        }
      }
    } catch (e) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _conversationMessages = cached
            .map((data) => MessageModel.fromJson(data))
            .toList();
        _error = null;
      } else {
        _error = e.toString();
        _conversationMessages = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessageStats(String token) async {
    try {
      final response = await _apiService.getMessageStats(token);
      _stats = response;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> loadEmployees(String token, {String? search}) async {
    try {
      final response = await _apiService.getEmployeesForMessaging(
        token,
        search: search,
        page: 1,
        limit: 50,
      );

      final List<dynamic> employeesData = response['employees'] ?? [];
      _employees = employeesData.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {}
  }

  Future<void> loadHRUsers(String token, {String? search}) async {
    try {
      final response = await _apiService.getHRForMessaging(
        token,
        search: search,
        page: 1,
        limit: 50,
      );

      final List<dynamic> hrUsersData = response['hrUsers'] ?? [];
      _hrUsers = hrUsersData.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {}
  }

  Future<bool> sendMessageToEmployee(
    String employeeId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.sendMessageToEmployee(
        employeeId,
        subject,
        content,
        token,
        priority: priority,
        attachments: attachments,
        scheduledFor: scheduledFor,
      );

      final newMessage = MessageModel.fromJson(response['data']);
      _messages.insert(0, newMessage);

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String receiverId,
    required String receiverType,
    required String subject,
    required String content,
    required String token,
    String priority = 'normal',
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
  }) async {
    bool success;
    if (receiverType == 'HR') {
      success = await sendMessageToHR(
        receiverId,
        subject,
        content,
        token,
        priority: priority,
        attachments: attachments,
        scheduledFor: scheduledFor,
      );
    } else {
      success = await sendMessageToEmployee(
        receiverId,
        subject,
        content,
        token,
        priority: priority,
        attachments: attachments,
        scheduledFor: scheduledFor,
      );
    }

    if (success) {
      await loadConversation(receiverId, receiverType, token, refresh: true);
    }

    return success;
  }

  Future<bool> sendMessageToHR(
    String hrId,
    String subject,
    String content,
    String token, {
    String priority = 'normal',
    List<Map<String, dynamic>>? attachments,
    DateTime? scheduledFor,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.sendMessageToHR(
        hrId,
        subject,
        content,
        token,
        priority: priority,
        attachments: attachments,
        scheduledFor: scheduledFor,
      );

      final newMessage = MessageModel.fromJson(response['data']);
      _messages.insert(0, newMessage);

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> markAsRead(String messageId, String token) async {
    try {
      await _apiService.markMessageAsRead(messageId, token);

      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isRead: true,
          readAt: DateTime.now(),
          status: 'read',
        );
      }

      final conversationIndex = _conversationMessages.indexWhere(
        (message) => message.id == messageId,
      );
      if (conversationIndex != -1) {
        _conversationMessages[conversationIndex] =
            _conversationMessages[conversationIndex].copyWith(
              isRead: true,
              readAt: DateTime.now(),
              status: 'read',
            );
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markMultipleAsRead(List<String> messageIds, String token) async {
    try {
      await _apiService.markMultipleMessagesAsRead(messageIds, token);

      for (final messageId in messageIds) {
        final index = _messages.indexWhere(
          (message) => message.id == messageId,
        );
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            isRead: true,
            readAt: DateTime.now(),
            status: 'read',
          );
        }

        final conversationIndex = _conversationMessages.indexWhere(
          (message) => message.id == messageId,
        );
        if (conversationIndex != -1) {
          _conversationMessages[conversationIndex] =
              _conversationMessages[conversationIndex].copyWith(
                isRead: true,
                readAt: DateTime.now(),
                status: 'read',
              );
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> archiveMessage(String messageId, String token) async {
    try {
      await _apiService.archiveMessage(messageId, token);

      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isArchived: true,
          archivedAt: DateTime.now(),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId, String token) async {
    try {
      await _apiService.deleteMessage(messageId, token);

      _messages.removeWhere((message) => message.id == messageId);
      _conversationMessages.removeWhere((message) => message.id == messageId);

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> refreshMessages(String token) async {
    await loadMessages(token, refresh: true, forceRefresh: true);
  }

  Future<void> loadMoreMessages(String token) async {
    if (!_isLoading && _hasMoreData) {
      await loadMessages(token);
    }
  }

  Future<void> loadMoreConversation(
    String userId,
    String userType,
    String token,
  ) async {
    if (!_isLoading && _hasMoreData) {
      await loadConversation(userId, userType, token);
    }
  }

  void clearData() {
    _messages.clear();
    _conversationMessages.clear();
    _employees.clear();
    _hrUsers.clear();
    _currentPage = 1;
    _hasMoreData = true;
    _isLoading = false;
    _error = null;
    _selectedMessageType = null;
    _selectedStatus = null;
    _selectedPriority = null;
    _showArchived = false;
    _stats = null;
    _currentConversationUserId = null;
    notifyListeners();
  }

  void handleMessageReceived(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;

      final transformedData = _transformWebSocketData(messageData);
      final newMessage = MessageModel.fromJson(transformedData);

      _messages.insert(0, newMessage);

      if (_currentConversationUserId != null) {
        final isFromCurrentUser =
            newMessage.senderId == _currentConversationUserId;
        final isToCurrentUser =
            newMessage.receiverId == _currentConversationUserId;

        if (isFromCurrentUser || isToCurrentUser) {
          final messageExists = _conversationMessages.any(
            (msg) => msg.id == newMessage.id,
          );

          if (!messageExists) {
            _conversationMessages.add(newMessage);

            _conversationMessages.sort(
              (a, b) => a.createdAt.compareTo(b.createdAt),
            );
          }
        } else {}
      } else {}

      notifyListeners();
    } catch (e) {}
  }

  void handleMessageSent(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;

      final transformedData = _transformWebSocketData(messageData);
      final newMessage = MessageModel.fromJson(transformedData);

      _messages.insert(0, newMessage);

      if (_currentConversationUserId != null) {
        final isFromCurrentUser =
            newMessage.senderId == _currentConversationUserId;
        final isToCurrentUser =
            newMessage.receiverId == _currentConversationUserId;

        if (isFromCurrentUser || isToCurrentUser) {
          final messageExists = _conversationMessages.any(
            (msg) => msg.id == newMessage.id,
          );

          if (!messageExists) {
            _conversationMessages.add(newMessage);

            _conversationMessages.sort(
              (a, b) => a.createdAt.compareTo(b.createdAt),
            );
          }
        } else {}
      } else {}

      notifyListeners();
    } catch (e) {}
  }

  void handleMessageRead(Map<String, dynamic> data) {
    try {
      final messageId = data['messageId'] ?? data['data']?['messageId'];
      if (messageId != null) {
        _updateMessageReadStatus(messageId, true);
        notifyListeners();
      }
    } catch (e) {}
  }

  void _updateMessageReadStatus(String messageId, bool isRead) {
    final messageIndex = _messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex != -1) {
      _messages[messageIndex] = _messages[messageIndex].copyWith(
        isRead: isRead,
        readAt: isRead ? DateTime.now() : null,
        status: isRead ? 'read' : 'sent',
      );
    }

    final conversationIndex = _conversationMessages.indexWhere(
      (message) => message.id == messageId,
    );
    if (conversationIndex != -1) {
      _conversationMessages[conversationIndex] =
          _conversationMessages[conversationIndex].copyWith(
            isRead: isRead,
            readAt: isRead ? DateTime.now() : null,
            status: isRead ? 'read' : 'sent',
          );
    }
  }

  Map<String, dynamic> _transformWebSocketData(Map<String, dynamic> data) {
    return {
      '_id': data['messageId'] ?? '',
      'sender': data['sender'] ?? {},
      'receiver': data['receiver'] ?? {},
      'senderModel': data['messageType']?.toString().contains('admin') == true
          ? 'Admin'
          : 'Employee',
      'receiverModel': data['messageType']?.toString().contains('admin') == true
          ? 'Employee'
          : 'Admin',
      'subject': data['subject'] ?? '',
      'content': data['content'] ?? '',
      'messageType': data['messageType'] ?? '',
      'priority': data['priority'] ?? 'normal',
      'status': 'sent',
      'isRead': false,
      'isArchived': false,
      'isReply': false,
      'attachments': [],
      'isScheduled': false,
      'deliveryAttempts': 0,
      'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  void setupWebSocketListeners(BuildContext context) {
    final webSocketProvider = Provider.of<WebSocketProvider>(
      context,
      listen: false,
    );

    webSocketProvider.messageStream.listen((data) {
      if (data.containsKey('messageId') ||
          data.containsKey('sender') ||
          data.containsKey('receiver') ||
          data.containsKey('content')) {
        if (data.containsKey('message') &&
            data['message'].toString().contains('received')) {
          handleMessageReceived(data);
        } else if (data.containsKey('message') &&
            data['message'].toString().contains('sent')) {
          handleMessageSent(data);
        } else {
          handleMessageReceived(data);
        }
      }
    });
  }
}

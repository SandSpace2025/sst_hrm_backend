import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';

import '../../core/models/conversation.dart';
import '../../core/models/message.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/hive_cache_service.dart';
import '../../core/services/notification_service.dart';
import '../providers/auth_provider.dart';

class MessagingProvider extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  String? _error;
  bool _hasMoreConversations = true;
  bool _hasMoreMessages = true;
  int _conversationPage = 1;
  int _messagePage = 1;

  static const String _conversationCacheBox = 'chatCache';

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreConversations => _hasMoreConversations;
  bool get hasMoreMessages => _hasMoreMessages;

  void initializeMessaging(String authToken) {
    _messagingService.setAuthToken(authToken);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
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

  Future<void> loadConversations({
    bool refresh = false,
    bool forceRefresh = false,
  }) async {
    try {
      if (refresh || forceRefresh) {
        _conversations.clear();
        _conversationPage = 1;
        _hasMoreConversations = true;
      }

      if (!_hasMoreConversations && !refresh && !forceRefresh) return;

      _setLoading(true);
      _setError(null);

      final role = _getUserRole();

      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedConversations(role);
        if (cached != null && cached.isNotEmpty) {
          _conversations = cached
              .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _setLoading(false);
          _setError(null);

          return;
        }
      }

      final online = await _isOnline();

      if (!online) {
        final cached = await HiveCacheService.getCachedConversations(role);
        if (cached != null && cached.isNotEmpty) {
          _conversations = cached
              .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _setError(null);
        } else {
          _conversations = [];
          _setError('No internet connection');
        }
        _setLoading(false);
        return;
      }

      try {
        final conversations = await _messagingService.getUserConversations(
          page: _conversationPage,
          limit: 20,
        );

        if (conversations.isEmpty) {
          _hasMoreConversations = false;
        } else {
          if (refresh || forceRefresh) {
            _conversations = conversations;
          } else {
            _conversations.addAll(conversations);
          }

          await HiveCacheService.cacheConversations(
            role,
            _conversations.map((c) => c.toJson()).toList(),
          );

          await _cacheUserProfilesFromConversations(_conversations);

          _conversationPage++;
        }
        _error = null;
      } on SocketException {
        final cached = await HiveCacheService.getCachedConversations(role);
        if (cached != null && cached.isNotEmpty) {
          _conversations = cached
              .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _error = null;
        } else {
          _error = 'No internet connection';
          _conversations = [];
        }
      } catch (e) {
        final cached = await HiveCacheService.getCachedConversations(role);
        if (cached != null && cached.isNotEmpty) {
          _conversations = cached
              .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _error = null;
        } else {
          _error = e.toString();
          _conversations = [];
        }
      }
    } catch (e) {
      final role = _getUserRole();
      final cached = await HiveCacheService.getCachedConversations(role);
      if (cached != null && cached.isNotEmpty) {
        _conversations = cached
            .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _error = null;
      } else {
        _error = e.toString();
        _conversations = [];
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreConversations() async {
    if (!_isLoading && _hasMoreConversations) {
      await loadConversations();
    }
  }

  Future<void> getConversation(String conversationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final conversation = await _messagingService.getConversation(
        conversationId,
      );
      _currentConversation = conversation;
    } catch (e) {
      _setError('Error getting conversation: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createConversation({
    required List<Map<String, dynamic>> participants,
    required String title,
    String? description,
    String conversationType = 'direct',
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final currentUserType = await _getCurrentUserType();
      final participantObjects = participants
          .map((p) => Participant.fromJson(p))
          .toList();

      if (!MessagingService.canCreateConversation(
        currentUserType,
        participantObjects,
      )) {
        _setError(
          'You are not authorized to create conversations with these participants',
        );
        return false;
      }

      final conversation = await _messagingService.createConversation(
        participants: participants,
        title: title,
        description: description,
        conversationType: conversationType,
      );

      _conversations.insert(0, conversation);
      _currentConversation = conversation;

      if (Hive.isBoxOpen(_conversationCacheBox)) {
        try {
          final box = Hive.box(_conversationCacheBox);
          await box.put(
            'conversations',
            _conversations.map((c) => c.toJson()).toList(),
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      _setError('Error creating conversation: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMessages({
    bool refresh = false,
    bool forceRefresh = false,
  }) async {
    if (_currentConversation == null) return;

    try {
      if (refresh || forceRefresh) {
        _messages.clear();
        _messagePage = 1;
        _hasMoreMessages = true;
      }

      if (!_hasMoreMessages && !refresh && !forceRefresh) return;

      _setLoading(true);
      _setError(null);

      final conversationId = _currentConversation!.conversationId;

      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationId,
        );
        if (cached != null && cached.isNotEmpty) {
          _messages = cached
              .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _setLoading(false);
          _setError(null);

          return;
        }
      }

      final online = await _isOnline();

      if (!online) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationId,
        );
        if (cached != null) {
          _messages = cached
              .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _setError(null);
        } else {
          _messages = [];
          _setError('No internet connection');
        }
        _setLoading(false);
        return;
      }

      try {
        final messages = await _messagingService.getConversationMessages(
          conversationId: conversationId,
          page: _messagePage,
          limit: 50,
        );

        if (messages.isEmpty) {
          _hasMoreMessages = false;

          // If refreshing and API returns empty, we should NOT clear _messages if we have cached data
          // potentially. But 'refresh' implies we want fresh data.
          // However, if the API is returning empty but we have local messages that haven't synced?
          // We'll trust the API is source of truth for "synced" messages.

          if (refresh || forceRefresh) {
            // If we force refreshed and got nothing, then truly there are no messages on server.
            // But we might want to keep what we have locally if we suspect server issue?
            // No, if forceRefresh is true, we should respect the empty list.
            // BUT, user says messages vanish.
            // If API returns empty list, and we clear local messages, that's correct BEHAVIOR if server has 0.
            // But if server is failing to return messages?
            // We'll proceed with clearing only if we are sure.
            // For now, let's just NOT write empty list to cache if we had something.
            if (_messages.isEmpty) {
              // If we had nothing and got nothing, sure.
            }
          }

          await HiveCacheService.cacheConversationMessages(
            conversationId,
            _messages.map((m) => m.toJson()).toList(),
          );
        } else {
          if (refresh || forceRefresh) {
            _messages = messages;
          } else {
            // Avoid duplicates when adding more messages
            final newMessages = messages.where((newMsg) {
              return !_messages.any(
                (existingMsg) => existingMsg.id == newMsg.id,
              );
            });
            _messages.addAll(newMessages);
            _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          await HiveCacheService.cacheConversationMessages(
            conversationId,
            _messages.map((m) => m.toJson()).toList(),
          );

          await _cacheUserProfilesFromMessages(_messages);

          _messagePage++;
        }
        _error = null;
      } on SocketException {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationId,
        );
        if (cached != null) {
          _messages = cached
              .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _error = null;
        } else {
          _error = 'No internet connection';
          _messages = [];
        }
      } catch (e) {
        final cached = await HiveCacheService.getCachedConversationMessages(
          conversationId,
        );
        if (cached != null) {
          _messages = cached
              .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _error = null;
        } else {
          _error = e.toString();
          _messages = [];
        }
      }
    } catch (e) {
      if (_messagePage == 1) {
        _setError(null);
        _hasMoreMessages = false;
      } else {
        _setError('Error loading messages: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_isLoading && _hasMoreMessages) {
      await loadMessages();
    }
  }

  Future<bool> sendMessage({
    required String content,
    String messageType = 'text',
    String? replyTo,
    String? conversationId,
  }) async {
    final targetConversationId =
        conversationId ?? _currentConversation?.conversationId;

    if (targetConversationId == null) {
      _setError(
        'No conversation selected. Please select a conversation first.',
      );
      return false;
    }

    if (content.trim().isEmpty) {
      _setError('Message content cannot be empty');
      return false;
    }

    try {
      _setLoading(true);
      _setError(null);

      final message = await _messagingService.sendMessage(
        conversationId: targetConversationId,
        content: content,
        messageType: messageType,
        replyTo: replyTo,
      );

      _messages.insert(0, message);

      await HiveCacheService.cacheConversationMessages(
        targetConversationId,
        _messages.map((m) => m.toJson()).toList(),
      );

      return true;
    } catch (e) {
      _setError('Error sending message: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _messagingService.markMessageAsRead(messageId);

      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  Future<void> markConversationAsRead() async {
    if (_currentConversation == null) return;
    try {
      await _messagingService.markConversationAsRead(
        _currentConversation!.conversationId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error marking conversation as read: $e');
      }
    }
  }

  Future<bool> addParticipant(Map<String, dynamic> participant) async {
    if (_currentConversation == null) return false;

    try {
      _setLoading(true);
      _setError(null);

      final updatedConversation = await _messagingService.addParticipant(
        _currentConversation!.conversationId,
        participant,
      );

      _currentConversation = updatedConversation;

      final index = _conversations.indexWhere(
        (c) => c.conversationId == updatedConversation.conversationId,
      );
      if (index != -1) {
        _conversations[index] = updatedConversation;
      }

      if (Hive.isBoxOpen(_conversationCacheBox)) {
        try {
          final box = Hive.box(_conversationCacheBox);
          await box.put(
            'conversations',
            _conversations.map((c) => c.toJson()).toList(),
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      _setError('Error adding participant: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeParticipant(String userId, String userType) async {
    if (_currentConversation == null) return false;

    try {
      _setLoading(true);
      _setError(null);

      final updatedConversation = await _messagingService.removeParticipant(
        _currentConversation!.conversationId,
        userId,
        userType,
      );

      _currentConversation = updatedConversation;

      final index = _conversations.indexWhere(
        (c) => c.conversationId == updatedConversation.conversationId,
      );
      if (index != -1) {
        _conversations[index] = updatedConversation;
      }

      if (Hive.isBoxOpen(_conversationCacheBox)) {
        try {
          final box = Hive.box(_conversationCacheBox);
          await box.put(
            'conversations',
            _conversations.map((c) => c.toJson()).toList(),
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      _setError('Error removing participant: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void setCurrentConversation(Conversation? conversation) {
    _currentConversation = conversation;
    if (conversation != null) {
      _messages.clear();
      _messagePage = 1;
      _hasMoreMessages = true;
    }
    notifyListeners();
  }

  void clearCurrentConversation() {
    _currentConversation = null;
    _messages.clear();
    _messagePage = 1;
    _hasMoreMessages = true;
    notifyListeners();
  }

  Future<void> refreshConversations() async {
    final online = await _isOnline();
    final context = NotificationService.globalNavigatorKey?.currentContext;
    if (context != null) {
      if (!online) {
        SnackBarUtils.showError(context, 'No internet connection');
      } else {
        SnackBarUtils.showInfo(context, 'Refreshing conversations...');
      }
    }
    await loadConversations(refresh: true, forceRefresh: true);
  }

  Future<void> refreshMessages() async {
    final online = await _isOnline();
    final context = NotificationService.globalNavigatorKey?.currentContext;

    if (!online) {
      _setError('No internet connection');
      if (context != null) {
        SnackBarUtils.showError(context, 'No internet connection');
      }
      return;
    }

    if (context != null) {
      SnackBarUtils.showInfo(context, 'Refreshing messages...');
    }

    try {
      await loadMessages(refresh: true, forceRefresh: true);
    } on SocketException {
      _setError('No internet connection');
      if (context != null) {
        SnackBarUtils.showError(context, 'No internet connection');
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('socketexception') ||
          e.toString().toLowerCase().contains('no internet')) {
        _setError('No internet connection');
        if (context != null) {
          SnackBarUtils.showError(context, 'No internet connection');
        }
      }
    }
  }

  Future<String> _getCurrentUserType() async {
    return _getUserRole();
  }

  bool canMessageUser(String receiverType) {
    final currentUserType = _getUserRole();
    return MessagingService.validateMessagingPermissions(
      currentUserType,
      receiverType,
    );
  }

  bool canCreateConversationWith(List<Participant> participants) {
    final currentUserType = _getUserRole();
    return MessagingService.canCreateConversation(
      currentUserType,
      participants,
    );
  }

  bool isViewingConversation(String? conversationId) {
    if (conversationId == null) return false;
    return _currentConversation?.conversationId == conversationId;
  }

  String? get currentConversationId => _currentConversation?.conversationId;

  void handleMessageReceived(Message message) {
    if (_currentConversation?.conversationId == message.conversationId) {
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.insert(0, message);
        _messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    }

    _updateConversationLastMessage(message);
  }

  void handleMessageSent(Message message) {
    if (_currentConversation?.conversationId == message.conversationId) {
      _messages.insert(0, message);
      notifyListeners();
    }
  }

  void handleMessageRead(String messageId, String conversationId) {
    if (_currentConversation?.conversationId == conversationId) {
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        notifyListeners();
      }
    }
  }

  void handleConversationCreated(Conversation conversation) {
    _conversations.insert(0, conversation);
    notifyListeners();
  }

  void handleConversationUpdated(Conversation conversation) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == conversation.conversationId,
    );

    if (index != -1) {
      _conversations[index] = conversation;
      notifyListeners();
    }

    if (_currentConversation?.conversationId == conversation.conversationId) {
      setCurrentConversation(conversation);
    }
  }

  void _updateConversationLastMessage(Message message) {
    final index = _conversations.indexWhere(
      (c) => c.conversationId == message.conversationId,
    );

    if (index != -1) {
      notifyListeners();
    }
  }

  Future<void> _cacheUserProfilesFromConversations(
    List<Conversation> conversations,
  ) async {
    try {
      for (final conversation in conversations) {
        for (final participant in conversation.participants) {
          if (participant.userId.isNotEmpty) {
            final profileData = {
              'userId': participant.userId,
              'userType': participant.userType,
              'name': participant.name ?? '',
              'email': participant.email ?? '',
              'userRole': participant.userRole ?? '',
            };
            await HiveCacheService.cacheUserProfile(
              participant.userId,
              profileData,
            );
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _cacheUserProfilesFromMessages(List<Message> messages) async {
    try {
      for (final message in messages) {
        final sender = message.sender;
        if (sender.userId.isNotEmpty) {
          final profileData = {
            'userId': sender.userId,
            'userType': sender.userType,
            'name': sender.name,
            'email': sender.email,
          };
          await HiveCacheService.cacheUserProfile(sender.userId, profileData);
        }
      }
    } catch (e) {}
  }

  void clearData() {
    _conversations = [];
    _messages = [];
    _currentConversation = null;
    _isLoading = false;
    _error = null;
    _hasMoreConversations = true;
    _hasMoreMessages = true;
    _conversationPage = 1;
    _messagePage = 1;
    notifyListeners();
  }
}

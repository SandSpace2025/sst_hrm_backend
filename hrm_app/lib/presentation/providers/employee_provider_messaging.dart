part of 'employee_provider.dart';

extension EmployeeProviderMessaging on EmployeeProvider {
  int get unreadMessagesCount => _unreadConversations.length;

  /// Update app badge count based on unread conversations
  Future<void> _updateAppBadge() async {
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
        // Attempt force update
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

  bool hasUnreadMessages(String senderId) {
    return _unreadConversations.contains(senderId);
  }

  void addUnreadConversation(String senderId) {
    if (senderId.isNotEmpty && !_unreadConversations.contains(senderId)) {
      _unreadConversations.add(senderId);
      _updateAppBadge(); // Update badge
      notifyListeners();
    }
  }

  void removeUnreadConversation(String senderId) {
    if (_unreadConversations.remove(senderId)) {
      _updateAppBadge(); // Update badge
      notifyListeners();
    }
  }

  void clearUnreadConversations() {
    if (_unreadConversations.isNotEmpty) {
      _unreadConversations.clear();
      _updateAppBadge(); // Update badge
      notifyListeners();
    }
  }

  void setUnreadConversations(List<dynamic> senderIds) {
    _unreadConversations.clear();
    for (var id in senderIds) {
      if (id != null) {
        _unreadConversations.add(id.toString());
      }
    }
    _updateAppBadge(); // Update badge
    notifyListeners();
  }

  Future<void> loadMessages(String token, {bool forceRefresh = false}) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final role = _userRole ?? 'employee';

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!forceRefresh) {
      final cached = await HiveCacheService.getCachedMessages(role);
      if (cached != null) {
        _messages = cached;
        _messagesLoadedFromCache = true;
        _isLoading = false;
        _notify();
        return;
      }
    }

    if (!isOnline) {
      final cached = await HiveCacheService.getCachedMessages(role);
      if (cached != null) {
        _messages = cached;
        _messagesLoadedFromCache = true;
        _isLoading = false;
        _notify();
        return;
      }
      _messages = [];
      _messagesLoadedFromCache = false;
      _isLoading = false;
      _notify();
      return;
    }

    try {
      final response = await _messagingRepository.getConversations(
        authToken,
        role: role,
      );
      _messages = response['conversations'] ?? [];

      await HiveCacheService.cacheMessages(role, _messages);
      _messagesLoadedFromCache = false;
      _error = null;
    } on SocketException {
      final cached = await HiveCacheService.getCachedMessages(role);
      if (cached != null) {
        _messages = cached;
        _messagesLoadedFromCache = true;
        _error = null;
      } else {
        _messagesLoadedFromCache = false;
        _error = 'No internet connection';
        _messages = [];
      }
    } catch (e) {
      final cached = await HiveCacheService.getCachedMessages(role);
      if (cached != null) {
        _messages = cached;
        _messagesLoadedFromCache = true;
        _error = null;
      } else {
        _messagesLoadedFromCache = false;
        _error = e.toString();
        _messages = [];
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> getConversation(
    String token,
    String userId,
    String userType, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    final currentUserRole = 'employee';
    final conversationKey =
        '${currentUserRole}_${userId}_${userType.toLowerCase()}';

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!forceRefresh) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _messagesLoadedFromCache = true;
        _isLoading = false;
        _error = null;
        return {'messages': _messages, 'conversation': _messages};
      }
    }

    if (!isOnline) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _messagesLoadedFromCache = true;
        _error = null;
      } else {
        _messages = [];
        _messagesLoadedFromCache = false;
        _error = null;
        return {'messages': _messages, 'conversation': _messages};
      }
    }

    if (!forceRefresh && _messagesLoadedFromCache && _messages.isNotEmpty) {
      _isLoading = false;
      _notify();
      return {'messages': _messages, 'conversation': _messages};
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _messagingRepository.getEmployeeConversation(
        userId,
        userType.toLowerCase(),
        authToken,
      );

      List<dynamic> extracted = [];
      final dynamic messages = response['messages'];
      final dynamic conversation = response['conversation'];
      final dynamic data = response['data'];

      if (messages is List) {
        extracted = messages;
      } else if (conversation is List) {
        extracted = conversation;
      } else if (conversation is Map && conversation['messages'] is List) {
        extracted = List<dynamic>.from(conversation['messages']);
      } else if (data is List) {
        extracted = data;
      } else if (data is Map && data['messages'] is List) {
        extracted = List<dynamic>.from(data['messages']);
      } else {
        final dynamic docs = response['docs'] ?? response['items'];
        if (docs is List) {
          extracted = docs;
        }
      }

      _messages = List<dynamic>.from(extracted);

      await HiveCacheService.cacheConversationMessages(
        conversationKey,
        _messages,
      );
      _messagesLoadedFromCache = false;

      _isLoading = false;
      _error = null;
      _notify();
      return response;
    } on SocketException {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _messagesLoadedFromCache = true;
        _error = null;
      } else {
        _messages = [];
        _messagesLoadedFromCache = false;
        _error = 'No internet connection';
      }
      _isLoading = false;
      _notify();
      return {'messages': _messages, 'conversation': _messages};
    } catch (e) {
      final cached = await HiveCacheService.getCachedConversationMessages(
        conversationKey,
      );
      if (cached != null) {
        _messages = List<dynamic>.from(cached);
        _messagesLoadedFromCache = true;
        _error = null;
      } else {
        _messagesLoadedFromCache = false;
        if (e.toString().toLowerCase().contains('not found')) {
          _error = null;
        } else {
          _error = e.toString();
        }
        _messages = [];
      }
      _isLoading = false;
      _notify();

      if (_error != null) {
        rethrow;
      }
      return {'messages': _messages, 'conversation': _messages};
    }
  }

  Future<void> markMessageAsRead(String token, String messageId) async {
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

      await _messagingRepository.markMessageAsRead(messageId, authToken);

      if (isOnline && !_dashboardLoadedFromCache) {
        await fetchEmployeeDashboardSummary(authToken, forceRefresh: false);
      }
    } catch (e) {}
  }

  Future<void> markConversationAsSeen(
    String token,
    String userId,
    String userType,
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

      await _messagingRepository.markConversationAsSeen(
        userId,
        userType,
        authToken,
      );

      // Optimistically remove unread status for this user
      removeUnreadConversation(userId);
    } catch (e) {}
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

    _isSendingMessage = true;
    _error = null;
    _notify();

    try {
      await _messagingRepository.sendEmployeeMessageToHR(
        hrId,
        subject,
        content,
        authToken,
        priority: priority,
      );

      // Refresh conversation to update local cache with the newly sent message
      await getConversation(authToken, hrId, 'hr', forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSendingMessage = false;
      _notify();
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

    _isSendingMessage = true;
    _error = null;
    _notify();

    try {
      await _messagingRepository.sendEmployeeMessageToAdmin(
        adminId,
        subject,
        content,
        authToken,
        priority: priority,
      );

      // Refresh conversation to update local cache
      await getConversation(authToken, adminId, 'admin', forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSendingMessage = false;
      _notify();
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

    _isSendingMessage = true;
    _error = null;
    _notify();

    try {
      await _messagingRepository.sendEmployeeMessageToEmployee(
        employeeId,
        subject,
        content,
        authToken,
        priority: priority,
      );

      // Refresh conversation to update local cache
      await getConversation(
        authToken,
        employeeId,
        'employee',
        forceRefresh: true,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSendingMessage = false;
      _notify();
    }
  }

  Future<void> loadHRContacts(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _hrContacts.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _messagingRepository.getEmployeeHRContacts(
        authToken,
      );
      _hrContacts = response['hrContacts'] ?? response['data'] ?? [];
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
      } else {
        // Don't set global error for contact loading failures to avoid blocking the UI
        print('Error loading HR contacts: $e');
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadAdminContacts(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _adminContacts.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _messagingRepository.getEmployeeAdminContacts(
        authToken,
      );
      _adminContacts = response['adminContacts'] ?? response['data'] ?? [];
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
      } else {
        // Don't set global error for admin contacts to avoid confusing "Admin not found" messages
        print('Error loading Admin contacts: $e');
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadEmployeeContactsForMessaging(
    String token, {
    String? search,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _employeeContacts.isNotEmpty) {
      return;
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _messagingRepository.getEmployeePeerContacts(
        authToken,
      );
      _employeeContacts =
          response['employeeContacts'] ?? response['data'] ?? [];
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
      } else {
        print('Error loading Employee contacts: $e');
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> checkMessagingPermission(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      final response = await _messagingRepository.checkMessagingPermission(
        authToken,
      );
      _messagingPermissions = response['permissions'];
      _notify();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<void> requestMessagingPermission(
    String token, {
    String? adminId,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      await _messagingRepository.requestMessagingPermission(
        authToken,
        adminId: adminId,
      );
      await checkMessagingPermission(authToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  bool get canMessage {
    if (_messagingPermissions == null) {
      return false;
    }

    final canMessage = _messagingPermissions!['canMessage'] ?? false;
    final expiresAt = _messagingPermissions!['expiresAt'];

    if (!canMessage || expiresAt == null) {
      return false;
    }

    try {
      final expiryDate = DateTime.parse(expiresAt);
      final now = DateTime.now();
      return now.isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  DateTime? get permissionExpiresAt {
    if (_messagingPermissions == null) return null;

    final expiresAt = _messagingPermissions!['expiresAt'];
    if (expiresAt == null) return null;

    try {
      return DateTime.parse(expiresAt);
    } catch (e) {
      return null;
    }
  }
}

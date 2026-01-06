import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/conversation.dart';
import '../../core/models/message.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/notification_service.dart';
import 'messaging_provider.dart';

class MessagingWebSocketProvider extends ChangeNotifier {
  final MessagingProvider _messagingProvider;
  final WebSocketService _webSocketService;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _messageSubscription;

  MessagingWebSocketProvider({
    required MessagingProvider messagingProvider,
    required WebSocketService webSocketService,
  }) : _messagingProvider = messagingProvider,
       _webSocketService = webSocketService;

  void initialize() {
    _setupWebSocketListeners();
    _notificationService.initialize();
  }

  void _setupWebSocketListeners() {
    _messageSubscription = _webSocketService.messageStream.listen((data) {
      _handleMessageEvent(data);
    });
  }

  void _handleMessageEvent(Map<String, dynamic> data) {
    final event = data['event'] ?? '';

    switch (event) {
      case 'message_received':
        _handleMessageReceived(data);
        break;
      case 'message_sent':
        _handleMessageSent(data);
        break;
      case 'message_read':
        _handleMessageRead(data);
        break;
      case 'conversation_created':
        _handleConversationCreated(data);
        break;
      case 'conversation_updated':
        _handleConversationUpdated(data);
        break;
      default:
    }
  }

  void _handleMessageReceived(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;

      final message = Message.fromJson(messageData);
      _messagingProvider.handleMessageReceived(message);
    } catch (e) {}
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;
      final message = Message.fromJson(messageData);
      _messagingProvider.handleMessageSent(message);
    } catch (e) {}
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] ?? data;
      final messageId = messageData['messageId'] ?? data['messageId'];
      final conversationId =
          messageData['conversationId'] ?? data['conversationId'];
      _messagingProvider.handleMessageRead(messageId, conversationId);
    } catch (e) {}
  }

  void _handleConversationCreated(Map<String, dynamic> data) {
    try {
      final conversationData = data['data'] ?? data;
      final conversation = conversationData['conversation'] ?? conversationData;

      final conversationMap = conversation is Map<String, dynamic>
          ? conversation
          : Map<String, dynamic>.from(conversation);
      _messagingProvider.handleConversationCreated(
        Conversation.fromJson(conversationMap),
      );
    } catch (e) {}
  }

  void _handleConversationUpdated(Map<String, dynamic> data) {
    try {
      final conversationData = data['data'] ?? data;
      final conversation = conversationData['conversation'] ?? conversationData;

      final conversationMap = conversation is Map<String, dynamic>
          ? conversation
          : Map<String, dynamic>.from(conversation);
      _messagingProvider.handleConversationUpdated(
        Conversation.fromJson(conversationMap),
      );
    } catch (e) {}
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

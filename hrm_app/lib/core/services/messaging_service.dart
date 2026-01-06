import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class MessagingService {
  static String get _baseUrl => AppConfig.apiBaseUrl;
  String? _authToken;

  MessagingService({String? authToken}) : _authToken = authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_authToken',
    };
  }

  static bool validateMessagingPermissions(
    String senderType,
    String receiverType,
  ) {
    if (senderType == 'admin') return true;

    if (senderType == 'hr') return true;

    if (senderType == 'employee') {
      if (receiverType == 'admin') return false;
      return true;
    }

    return false;
  }

  static bool canCreateConversation(
    String userType,
    List<Participant> participants,
  ) {
    for (final participant in participants) {
      if (!validateMessagingPermissions(userType, participant.userType)) {
        return false;
      }
    }
    return true;
  }

  Future<Conversation> createConversation({
    required List<Map<String, dynamic>> participants,
    required String title,
    String? description,
    String conversationType = 'direct',
  }) async {
    try {
      final currentUserType = await _getCurrentUserType();
      final participantObjects = participants
          .map((p) => Participant.fromJson(p))
          .toList();

      if (!canCreateConversation(currentUserType, participantObjects)) {
        throw Exception(
          'You are not authorized to create conversations with these participants',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/conversations'),
        headers: _headers,
        body: jsonEncode({
          'participants': participants,
          'title': title,
          'description': description,
          'conversationType': conversationType,
        }),
      );

      debugPrint(
        'Create Conversation Response: ${response.statusCode} - ${response.body}',
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final conversationData = data['conversation'];
        final conversationMap = conversationData is Map<String, dynamic>
            ? conversationData
            : Map<String, dynamic>.from(conversationData);
        return Conversation.fromJson(conversationMap);
      } else {
        final errorData = jsonDecode(response.body);
        final errorCode = errorData['code'] ?? 'UNKNOWN_ERROR';
        final errorMessage =
            errorData['message'] ?? 'Failed to create conversation';

        if (errorCode == 'MISSING_ENCRYPTION_KEYS') {
          throw Exception(
            'Some participants need to initialize their encryption keys. Please ask them to log in and set up their messaging keys.',
          );
        } else if (errorCode == 'KEY_INITIALIZATION_FAILED') {
          throw Exception(
            'Failed to initialize encryption keys. Please try again.',
          );
        } else if (errorCode == 'MESSAGING_NOT_ALLOWED') {
          throw Exception(
            'You are not authorized to create conversations with these participants.',
          );
        } else if (errorCode == 'INVALID_PARTICIPANTS') {
          throw Exception(
            'At least 2 participants are required for a conversation.',
          );
        }

        throw Exception('Failed to create conversation: $errorMessage');
      }
    } catch (e) {
      throw Exception('Error creating conversation: $e');
    }
  }

  Future<List<Conversation>> getUserConversations({
    int page = 1,
    int limit = 20,
    bool isArchived = false,
    String? conversationType,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'isArchived': isArchived.toString(),
        if (conversationType != null) 'conversationType': conversationType,
      };

      final uri = Uri.parse(
        '$_baseUrl/conversations',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['conversations'] as List<dynamic>).map((c) {
          final conversationMap = c is Map<String, dynamic>
              ? c
              : Map<String, dynamic>.from(c);
          return Conversation.fromJson(conversationMap);
        }).toList();
      } else {
        throw Exception('Failed to get conversations: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting conversations: $e');
    }
  }

  Future<Conversation> getConversation(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/conversations/$conversationId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final conversationData = data['conversation'];
        final conversationMap = conversationData is Map<String, dynamic>
            ? conversationData
            : Map<String, dynamic>.from(conversationData);
        return Conversation.fromJson(conversationMap);
      } else if (response.statusCode == 404) {
        throw Exception('Conversation not found');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to get conversation';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Error getting conversation: $e');
    }
  }

  Future<Conversation> addParticipant(
    String conversationId,
    Map<String, dynamic> participant,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/conversations/$conversationId/participants'),
        headers: _headers,
        body: jsonEncode(participant),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final conversationData = data['conversation'];
        final conversationMap = conversationData is Map<String, dynamic>
            ? conversationData
            : Map<String, dynamic>.from(conversationData);
        return Conversation.fromJson(conversationMap);
      } else {
        throw Exception('Failed to add participant: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding participant: $e');
    }
  }

  Future<Conversation> removeParticipant(
    String conversationId,
    String userId,
    String userType,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/conversations/$conversationId/participants'),
        headers: _headers,
        body: jsonEncode({'userId': userId, 'userType': userType}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final conversationData = data['conversation'];
        final conversationMap = conversationData is Map<String, dynamic>
            ? conversationData
            : Map<String, dynamic>.from(conversationData);
        return Conversation.fromJson(conversationMap);
      } else {
        throw Exception('Failed to remove participant: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error removing participant: $e');
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? replyTo,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception('conversationId is required');
      }
      if (content.isEmpty) {
        throw Exception('content is required');
      }

      final requestBody = {
        'conversationId': conversationId,
        'content': content,
        'messageType': messageType,
        if (replyTo != null) 'replyTo': replyTo,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/messages-v2'),
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        return Message.fromJson(data['messageData']);
      } else {
        final errorBody = response.body;
        throw Exception('Failed to send message: $errorBody');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<List<Message>> getConversationMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = {'page': page.toString(), 'limit': limit.toString()};

      final uri = Uri.parse(
        '$_baseUrl/messages-v2/conversation/$conversationId',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List<dynamic>)
            .map((m) => Message.fromJson(m))
            .toList();
        return messages;
      } else if (response.statusCode == 404) {
        return [];
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to get messages';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (e.toString().contains('conversation not found') ||
          e.toString().contains('404')) {
        return [];
      }
      throw Exception('Error getting messages: $e');
    }
  }

  Future<Message> getMessage(String messageId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages-v2/$messageId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Message.fromJson(data['message']);
      } else {
        throw Exception('Failed to get message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting message: $e');
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/messages-v2/$messageId/read'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark message as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error marking message as read: $e');
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/conversations/$conversationId/read'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to mark conversation as read: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error marking conversation as read: $e');
    }
  }

  Future<String> _getCurrentUserType() async {
    return 'employee';
  }
}

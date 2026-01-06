class Conversation {
  final String conversationId;
  final String title;
  final String description;
  final String conversationType;
  final List<Participant> participants;
  final ConversationSettings settings;
  final DateTime lastMessageAt;
  final String? lastMessageId;
  final int messageCount;
  final int unreadCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.conversationId,
    required this.title,
    required this.description,
    required this.conversationType,
    required this.participants,
    required this.settings,
    required this.lastMessageAt,
    this.lastMessageId,
    required this.messageCount,
    required this.unreadCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(dynamic json) {
    final jsonMap = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);

    return Conversation(
      conversationId: jsonMap['conversationId'] ?? '',
      title: jsonMap['title'] ?? '',
      description: jsonMap['description'] ?? '',
      conversationType: jsonMap['conversationType'] ?? 'direct',
      participants:
          (jsonMap['participants'] as List<dynamic>?)
              ?.map(
                (p) => Participant.fromJson(
                  p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p),
                ),
              )
              .toList() ??
          [],
      settings: ConversationSettings.fromJson(
        jsonMap['settings'] is Map<String, dynamic>
            ? (jsonMap['settings'] as Map<String, dynamic>)
            : jsonMap['settings'] != null
            ? Map<String, dynamic>.from(jsonMap['settings'])
            : {},
      ),
      lastMessageAt: DateTime.parse(
        jsonMap['lastMessageAt'] ?? DateTime.now().toIso8601String(),
      ),
      lastMessageId: jsonMap['lastMessageId'],
      messageCount: jsonMap['messageCount'] ?? 0,
      unreadCount: jsonMap['unreadCount'] ?? 0,
      status: jsonMap['status'] ?? 'active',
      createdAt: DateTime.parse(
        jsonMap['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        jsonMap['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'title': title,
      'description': description,
      'conversationType': conversationType,
      'participants': participants.map((p) => p.toJson()).toList(),
      'settings': settings.toJson(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessageId': lastMessageId,
      'messageCount': messageCount,
      'unreadCount': unreadCount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool isParticipant(String userId, String userType) {
    return participants.any(
      (p) => p.userId == userId && p.userType == userType,
    );
  }

  List<Participant> get activeParticipants {
    return participants.where((p) => p.isActive).toList();
  }

  bool get isDirect => conversationType == 'direct';
  bool get isGroup => conversationType == 'group';
  bool get isSupport => conversationType == 'support';
  bool get isAnnouncement => conversationType == 'announcement';
}

class Participant {
  final String userId;
  final String userType;
  final String? userRole;
  final String? name;
  final String? email;
  final DateTime joinedAt;
  final bool isActive;
  final DateTime lastSeenAt;

  Participant({
    required this.userId,
    required this.userType,
    this.userRole,
    this.name,
    this.email,
    required this.joinedAt,
    required this.isActive,
    required this.lastSeenAt,
  });

  factory Participant.fromJson(dynamic json) {
    final jsonMap = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);

    return Participant(
      userId: jsonMap['userId'] ?? '',
      userType: jsonMap['userType'] ?? '',
      userRole: jsonMap['userRole'],
      name: jsonMap['name'],
      email: jsonMap['email'],
      joinedAt: DateTime.parse(
        jsonMap['joinedAt'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: jsonMap['isActive'] ?? true,
      lastSeenAt: DateTime.parse(
        jsonMap['lastSeenAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userType': userType,
      'userRole': userRole,
      'name': name,
      'email': email,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      'lastSeenAt': lastSeenAt.toIso8601String(),
    };
  }
}

class ConversationSettings {
  final bool allowNewParticipants;
  final bool requireApproval;
  final bool isArchived;
  final bool isPinned;
  final bool muteNotifications;

  ConversationSettings({
    required this.allowNewParticipants,
    required this.requireApproval,
    required this.isArchived,
    required this.isPinned,
    required this.muteNotifications,
  });

  factory ConversationSettings.fromJson(dynamic json) {
    final jsonMap = json is Map<String, dynamic>
        ? json
        : Map<String, dynamic>.from(json as Map);

    return ConversationSettings(
      allowNewParticipants: jsonMap['allowNewParticipants'] ?? false,
      requireApproval: jsonMap['requireApproval'] ?? false,
      isArchived: jsonMap['isArchived'] ?? false,
      isPinned: jsonMap['isPinned'] ?? false,
      muteNotifications: jsonMap['muteNotifications'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowNewParticipants': allowNewParticipants,
      'requireApproval': requireApproval,
      'isArchived': isArchived,
      'isPinned': isPinned,
      'muteNotifications': muteNotifications,
    };
  }
}

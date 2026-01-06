class Message {
  final String id;
  final String conversationId;
  final MessageSender sender;
  final String content;
  final String messageType;
  final String priority;
  final String status;
  final List<ReadReceipt> readBy;
  final String? replyTo;
  final bool isReply;
  final List<MessageAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.content,
    required this.messageType,
    required this.priority,
    required this.status,
    required this.readBy,
    this.replyTo,
    required this.isReply,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      sender: MessageSender.fromJson(json['sender'] ?? {}),
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'text',
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'sent',
      readBy:
          (json['readBy'] as List<dynamic>?)
              ?.map((r) => ReadReceipt.fromJson(r))
              .toList() ??
          [],
      replyTo: json['replyTo'],
      isReply: json['isReply'] ?? false,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((a) => MessageAttachment.fromJson(a))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender.toJson(),
      'content': content,
      'messageType': messageType,
      'priority': priority,
      'status': status,
      'readBy': readBy.map((r) => r.toJson()).toList(),
      'replyTo': replyTo,
      'isReply': isReply,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool isReadBy(String userId, String userType) {
    return readBy.any((r) => r.userId == userId && r.userType == userType);
  }

  int get readCount => readBy.length;
  bool get isText => messageType == 'text';
  bool get isFile => messageType == 'file';
  bool get isImage => messageType == 'image';
  bool get isSystem => messageType == 'system';
  bool get isAnnouncement => messageType == 'announcement';
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
}

class MessageSender {
  final String userId;
  final String userType;
  final String name;
  final String email;

  MessageSender({
    required this.userId,
    required this.userType,
    required this.name,
    required this.email,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) {
    return MessageSender(
      userId: json['userId'] ?? '',
      userType: json['userType'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userType': userType,
      'name': name,
      'email': email,
    };
  }
}

class ReadReceipt {
  final String userId;
  final String userType;
  final DateTime readAt;

  ReadReceipt({
    required this.userId,
    required this.userType,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      userId: json['userId'] ?? '',
      userType: json['userType'] ?? '',
      readAt: DateTime.parse(
        json['readAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userType': userType,
      'readAt': readAt.toIso8601String(),
    };
  }
}

class MessageAttachment {
  final String filename;
  final String originalName;
  final String encryptedPath;
  final int fileSize;
  final String mimeType;
  final bool encrypted;
  final DateTime uploadedAt;

  MessageAttachment({
    required this.filename,
    required this.originalName,
    required this.encryptedPath,
    required this.fileSize,
    required this.mimeType,
    required this.encrypted,
    required this.uploadedAt,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      filename: json['filename'] ?? '',
      originalName: json['originalName'] ?? '',
      encryptedPath: json['encryptedPath'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
      encrypted: json['encrypted'] ?? true,
      uploadedAt: DateTime.parse(
        json['uploadedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalName': originalName,
      'encryptedPath': encryptedPath,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'encrypted': encrypted,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

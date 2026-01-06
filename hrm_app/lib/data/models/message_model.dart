class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderEmail;
  final String senderModel;
  final String receiverId;
  final String receiverName;
  final String receiverEmail;
  final String receiverModel;
  final String subject;
  final String content;
  final String messageType;
  final String priority;
  final String status;
  final bool isRead;
  final DateTime? readAt;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? parentMessageId;
  final bool isReply;
  final List<MessageAttachment> attachments;
  final DateTime? scheduledFor;
  final bool isScheduled;
  final String? templateId;
  final int deliveryAttempts;
  final DateTime? lastDeliveryAttempt;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
    required this.senderModel,
    required this.receiverId,
    required this.receiverName,
    required this.receiverEmail,
    required this.receiverModel,
    required this.subject,
    required this.content,
    required this.messageType,
    required this.priority,
    required this.status,
    required this.isRead,
    this.readAt,
    required this.isArchived,
    this.archivedAt,
    this.parentMessageId,
    required this.isReply,
    required this.attachments,
    this.scheduledFor,
    required this.isScheduled,
    this.templateId,
    required this.deliveryAttempts,
    this.lastDeliveryAttempt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? '',
      senderId: json['sender']?['_id'] ?? '',
      senderName: json['sender']?['fullName'] ?? json['sender']?['name'] ?? '',
      senderEmail: json['sender']?['email'] ?? '',
      senderModel: json['senderModel'] ?? '',
      receiverId: json['receiver']?['_id'] ?? '',
      receiverName:
          json['receiver']?['fullName'] ?? json['receiver']?['name'] ?? '',
      receiverEmail: json['receiver']?['email'] ?? '',
      receiverModel: json['receiverModel'] ?? '',
      subject: json['subject'] ?? '',
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? '',
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'sent',
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isArchived: json['isArchived'] ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'])
          : null,
      parentMessageId: json['parentMessage'],
      isReply: json['isReply'] ?? false,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((attachment) => MessageAttachment.fromJson(attachment))
              .toList() ??
          [],
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'])
          : null,
      isScheduled: json['isScheduled'] ?? false,
      templateId: json['templateId'],
      deliveryAttempts: json['deliveryAttempts'] ?? 0,
      lastDeliveryAttempt: json['lastDeliveryAttempt'] != null
          ? DateTime.parse(json['lastDeliveryAttempt'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'senderModel': senderModel,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverEmail': receiverEmail,
      'receiverModel': receiverModel,
      'subject': subject,
      'content': content,
      'messageType': messageType,
      'priority': priority,
      'status': status,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'parentMessageId': parentMessageId,
      'isReply': isReply,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      'scheduledFor': scheduledFor?.toIso8601String(),
      'isScheduled': isScheduled,
      'templateId': templateId,
      'deliveryAttempts': deliveryAttempts,
      'lastDeliveryAttempt': lastDeliveryAttempt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSendJson() {
    return {
      'subject': subject,
      'content': content,
      'priority': priority,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderEmail,
    String? senderModel,
    String? receiverId,
    String? receiverName,
    String? receiverEmail,
    String? receiverModel,
    String? subject,
    String? content,
    String? messageType,
    String? priority,
    String? status,
    bool? isRead,
    DateTime? readAt,
    bool? isArchived,
    DateTime? archivedAt,
    String? parentMessageId,
    bool? isReply,
    List<MessageAttachment>? attachments,
    DateTime? scheduledFor,
    bool? isScheduled,
    String? templateId,
    int? deliveryAttempts,
    DateTime? lastDeliveryAttempt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      senderModel: senderModel ?? this.senderModel,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      receiverModel: receiverModel ?? this.receiverModel,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      isReply: isReply ?? this.isReply,
      attachments: attachments ?? this.attachments,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isScheduled: isScheduled ?? this.isScheduled,
      templateId: templateId ?? this.templateId,
      deliveryAttempts: deliveryAttempts ?? this.deliveryAttempts,
      lastDeliveryAttempt: lastDeliveryAttempt ?? this.lastDeliveryAttempt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get priorityDisplayName {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'read':
        return 'Read';
      case 'archived':
        return 'Archived';
      default:
        return status;
    }
  }

  String get messageTypeDisplayName {
    switch (messageType.toLowerCase()) {
      case 'admin_to_employee':
        return 'To Employee';
      case 'admin_to_hr':
        return 'To HR';
      case 'hr_to_admin':
        return 'From HR';
      case 'employee_to_admin':
        return 'From Employee';
      default:
        return messageType;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  bool get isFromAdmin => senderModel.toLowerCase() == 'admin';
  bool get isToAdmin => receiverModel.toLowerCase() == 'admin';
  bool get isFromEmployee => senderModel.toLowerCase() == 'employee';
  bool get isToEmployee => receiverModel.toLowerCase() == 'employee';
}

class MessageAttachment {
  final String filename;
  final String originalName;
  final String path;
  final int fileSize;
  final String mimeType;
  final DateTime uploadedAt;

  MessageAttachment({
    required this.filename,
    required this.originalName,
    required this.path,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedAt,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      filename: json['filename'] ?? '',
      originalName: json['originalName'] ?? '',
      path: json['path'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalName': originalName,
      'path': path,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

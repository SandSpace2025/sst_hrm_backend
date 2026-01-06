class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final String audience;
  final String priority;
  final String createdById;
  final String createdByName;
  final String createdByDesignation;
  final bool isActive;
  final DateTime? scheduledFor;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.priority,
    required this.createdById,
    required this.createdByName,
    required this.createdByDesignation,
    required this.isActive,
    this.scheduledFor,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final announcement = AnnouncementModel(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      audience: json['audience'] ?? 'all',
      priority: json['priority'] ?? 'normal',
      createdById: json['createdBy'] is String
          ? json['createdBy']
          : json['createdBy']?['_id'] ?? '',
      createdByName: json['createdBy'] is Map
          ? (json['createdBy']?['fullName'] ??
                json['createdBy']?['name'] ??
                json['createdBy']?['email'] ??
                '')
          : '',
      createdByDesignation: json['createdBy'] is Map
          ? (json['createdBy']?['designation'] ?? '')
          : '',
      isActive: json['isActive'] ?? true,
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );

    return announcement;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'audience': audience,
      'priority': priority,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdByDesignation': createdByDesignation,
      'isActive': isActive,
      'scheduledFor': scheduledFor?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'message': message,
      'audience': audience,
      'priority': priority,
      if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'message': message,
      'audience': audience,
      'priority': priority,
      'isActive': isActive,
      if (scheduledFor != null) 'scheduledFor': scheduledFor!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? message,
    String? audience,
    String? priority,
    String? createdById,
    String? createdByName,
    String? createdByDesignation,
    bool? isActive,
    DateTime? scheduledFor,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      audience: audience ?? this.audience,
      priority: priority ?? this.priority,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      createdByDesignation: createdByDesignation ?? this.createdByDesignation,
      isActive: isActive ?? this.isActive,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
        return 'Normal';
    }
  }

  String get audienceDisplayName {
    switch (audience.toLowerCase()) {
      case 'all':
        return 'Everyone';
      case 'employees':
        return 'Employees';
      case 'hr':
        return 'HR Team';
      case 'admin':
        return 'Administrators';
      default:
        return 'Everyone';
    }
  }

  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    // 0, 1, 2, 3, 4 days difference covers 5 calendar days (Today + 4 previous days)
    return difference.inDays <= 4;
  }
}

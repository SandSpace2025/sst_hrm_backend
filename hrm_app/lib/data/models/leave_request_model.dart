class LeaveRequestModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final String employeeIdNumber;
  final String employeeJobTitle;
  final String employeePhone;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String reason;
  final String status;
  final String adminComments;
  final String? reviewedById;
  final String? reviewedByName;
  final String? reviewedByDesignation;
  final DateTime? reviewedAt;

  final String? hrApprovalStatus;
  final String? hrApprovedById;
  final String? hrApprovedByName;
  final DateTime? hrApprovedAt;
  final String? hrRejectionReason;

  final String? adminApprovalStatus;
  final String? adminApprovedById;
  final String? adminApprovedByName;
  final DateTime? adminApprovedAt;
  final String? adminRejectionReason;
  final bool isEmergency;
  final List<LeaveAttachment> attachments;
  final double leaveBalance;
  final bool isHalfDay;
  final String? halfDayType;
  final double? permissionHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.employeeIdNumber,
    required this.employeeJobTitle,
    required this.employeePhone,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.adminComments,
    this.reviewedById,
    this.reviewedByName,
    this.reviewedByDesignation,
    this.reviewedAt,
    this.hrApprovalStatus,
    this.hrApprovedById,
    this.hrApprovedByName,
    this.hrApprovedAt,
    this.hrRejectionReason,
    this.adminApprovalStatus,
    this.adminApprovedById,
    this.adminApprovedByName,
    this.adminApprovedAt,
    this.adminRejectionReason,
    required this.isEmergency,
    required this.attachments,
    required this.leaveBalance,
    required this.isHalfDay,
    this.halfDayType,
    this.permissionHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return LeaveRequestModel(
      id: json['_id'] ?? '',
      employeeId: json['employee']?['_id'] ?? '',
      employeeName: json['employee']?['name'] ?? '',
      employeeEmail: json['employee']?['email'] ?? '',
      employeeIdNumber: json['employee']?['employeeId'] ?? '',
      employeeJobTitle: json['employee']?['jobTitle'] ?? '',
      employeePhone: json['employee']?['phone'] ?? '',
      leaveType: json['leaveType'] ?? '',
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      totalDays: parseDouble(json['totalDays']),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      adminComments: json['adminComments'] ?? '',
      reviewedById: json['reviewedBy']?['_id'],
      reviewedByName: json['reviewedBy']?['fullName'],
      reviewedByDesignation: json['reviewedBy']?['designation'],
      reviewedAt: parseNullableDate(json['reviewedAt']),

      hrApprovalStatus: json['hrApproval']?['status'],
      hrApprovedById: json['hrApproval']?['approvedBy']?['_id'],
      hrApprovedByName: json['hrApproval']?['approvedBy']?['name'],
      hrApprovedAt: parseNullableDate(json['hrApproval']?['approvedAt']),
      hrRejectionReason: json['hrApproval']?['rejectionReason'],

      adminApprovalStatus: json['adminApproval']?['status'],
      adminApprovedById: json['adminApproval']?['approvedBy']?['_id'],
      adminApprovedByName: json['adminApproval']?['approvedBy']?['fullName'],
      adminApprovedAt: parseNullableDate(json['adminApproval']?['approvedAt']),
      adminRejectionReason: json['adminApproval']?['rejectionReason'],
      isEmergency: json['isEmergency'] ?? false,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map((attachment) => LeaveAttachment.fromJson(attachment))
              .toList() ??
          [],
      leaveBalance: parseDouble(json['leaveBalance']),
      isHalfDay: json['isHalfDay'] ?? false,
      halfDayType: json['halfDayType'],
      permissionHours: parseDouble(json['permissionHours']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeEmail': employeeEmail,
      'employeeIdNumber': employeeIdNumber,
      'employeeJobTitle': employeeJobTitle,
      'employeePhone': employeePhone,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalDays': totalDays,
      'reason': reason,
      'status': status,
      'adminComments': adminComments,
      'reviewedById': reviewedById,
      'reviewedByName': reviewedByName,
      'reviewedByDesignation': reviewedByDesignation,
      'reviewedAt': reviewedAt?.toIso8601String(),

      'hrApprovalStatus': hrApprovalStatus,
      'hrApprovedById': hrApprovedById,
      'hrApprovedByName': hrApprovedByName,
      'hrApprovedAt': hrApprovedAt?.toIso8601String(),
      'hrRejectionReason': hrRejectionReason,

      'adminApprovalStatus': adminApprovalStatus,
      'adminApprovedById': adminApprovedById,
      'adminApprovedByName': adminApprovedByName,
      'adminApprovedAt': adminApprovedAt?.toIso8601String(),
      'adminRejectionReason': adminRejectionReason,
      'isEmergency': isEmergency,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      'leaveBalance': leaveBalance,
      'isHalfDay': isHalfDay,
      'halfDayType': halfDayType,
      'permissionHours': permissionHours,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {'status': status, 'adminComments': adminComments};
  }

  LeaveRequestModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeeEmail,
    String? employeeIdNumber,
    String? employeeJobTitle,
    String? employeePhone,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    double? totalDays,
    String? reason,
    String? status,
    String? adminComments,
    String? reviewedById,
    String? reviewedByName,
    String? reviewedByDesignation,
    DateTime? reviewedAt,
    String? hrApprovalStatus,
    String? hrApprovedById,
    String? hrApprovedByName,
    DateTime? hrApprovedAt,
    String? hrRejectionReason,
    String? adminApprovalStatus,
    String? adminApprovedById,
    String? adminApprovedByName,
    DateTime? adminApprovedAt,
    String? adminRejectionReason,
    bool? isEmergency,
    List<LeaveAttachment>? attachments,
    double? leaveBalance,
    bool? isHalfDay,
    String? halfDayType,
    double? permissionHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequestModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      employeeIdNumber: employeeIdNumber ?? this.employeeIdNumber,
      employeeJobTitle: employeeJobTitle ?? this.employeeJobTitle,
      employeePhone: employeePhone ?? this.employeePhone,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminComments: adminComments ?? this.adminComments,
      reviewedById: reviewedById ?? this.reviewedById,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedByDesignation:
          reviewedByDesignation ?? this.reviewedByDesignation,
      reviewedAt: reviewedAt ?? this.reviewedAt,

      hrApprovalStatus: hrApprovalStatus ?? this.hrApprovalStatus,
      hrApprovedById: hrApprovedById ?? this.hrApprovedById,
      hrApprovedByName: hrApprovedByName ?? this.hrApprovedByName,
      hrApprovedAt: hrApprovedAt ?? this.hrApprovedAt,
      hrRejectionReason: hrRejectionReason ?? this.hrRejectionReason,

      adminApprovalStatus: adminApprovalStatus ?? this.adminApprovalStatus,
      adminApprovedById: adminApprovedById ?? this.adminApprovedById,
      adminApprovedByName: adminApprovedByName ?? this.adminApprovedByName,
      adminApprovedAt: adminApprovedAt ?? this.adminApprovedAt,
      adminRejectionReason: adminRejectionReason ?? this.adminRejectionReason,
      isEmergency: isEmergency ?? this.isEmergency,
      attachments: attachments ?? this.attachments,
      leaveBalance: leaveBalance ?? this.leaveBalance,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDayType: halfDayType ?? this.halfDayType,
      permissionHours: permissionHours ?? this.permissionHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'on_hold':
        return 'On Hold';
      default:
        return 'Unknown';
    }
  }

  String get leaveTypeDisplayName {
    switch (leaveType.toLowerCase()) {
      case 'sick':
        return 'Sick Leave';
      case 'vacation':
        return 'Vacation';
      case 'personal':
        return 'Personal';
      case 'maternity':
        return 'Maternity';
      case 'paternity':
        return 'Paternity';
      case 'bereavement':
        return 'Bereavement';
      case 'medical':
        return 'Medical';
      case 'other':
        return 'Other';
      default:
        return leaveType;
    }
  }

  String get durationText {
    double calculatedDays = totalDays;

    if (totalDays == 0 && isHalfDay) {
      calculatedDays = 0.5;
    } else if (totalDays == 0 &&
        permissionHours != null &&
        permissionHours! > 0) {
      calculatedDays = permissionHours! / 8;
    } else if (totalDays == 0) {
      final difference = endDate.difference(startDate).inDays;
      calculatedDays = (difference > 0 ? difference : 1).toDouble();
    }

    if (isHalfDay || calculatedDays == 0.5) {
      return 'Half Day (${halfDayType == 'first_half' ? 'First Half' : 'Second Half'})';
    }

    if (calculatedDays < 1 && calculatedDays != 0.5) {
      final hours = (calculatedDays * 8).round();
      return '$hours Hour${hours == 1 ? '' : 's'}';
    }

    final days = calculatedDays.round();

    return '$days ${days == 1 ? 'Day' : 'Days'}';
  }

  String get dateRangeText {
    final start = '${startDate.day}/${startDate.month}/${startDate.year}';
    final end = '${endDate.day}/${endDate.month}/${endDate.year}';
    return start == end ? start : '$start - $end';
  }

  bool get isPastLeave => startDate.isBefore(DateTime.now());
  bool get isUpcomingLeave => startDate.isAfter(DateTime.now());
  bool get isCurrentLeave =>
      startDate.isBefore(DateTime.now()) && endDate.isAfter(DateTime.now());

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

  String? get approverInfo {
    if (status == 'approved') {
      if (adminApprovalStatus == 'approved' && adminApprovedByName != null) {
        return 'Approved by Admin: $adminApprovedByName';
      }

      if (hrApprovalStatus == 'approved' && hrApprovedByName != null) {
        return 'Approved by HR: $hrApprovedByName';
      }

      if (reviewedByName != null) {
        return 'Approved by: $reviewedByName';
      }
    } else if (status == 'rejected') {
      if (adminApprovalStatus == 'rejected' && adminApprovedByName != null) {
        return 'Rejected by Admin: $adminApprovedByName';
      }

      if (hrApprovalStatus == 'rejected' && hrApprovedByName != null) {
        return 'Rejected by HR: $hrApprovedByName';
      }

      if (reviewedByName != null) {
        return 'Rejected by: $reviewedByName';
      }
    }
    return null;
  }

  DateTime? get approvalTimestamp {
    if (status == 'approved' || status == 'rejected') {
      if (adminApprovedAt != null) {
        return adminApprovedAt;
      }

      if (hrApprovedAt != null) {
        return hrApprovedAt;
      }

      return reviewedAt;
    }
    return null;
  }
}

class LeaveAttachment {
  final String filename;
  final String originalName;
  final String path;
  final DateTime uploadedAt;

  LeaveAttachment({
    required this.filename,
    required this.originalName,
    required this.path,
    required this.uploadedAt,
  });

  factory LeaveAttachment.fromJson(Map<String, dynamic> json) {
    return LeaveAttachment(
      filename: json['filename'] ?? '',
      originalName: json['originalName'] ?? '',
      path: json['path'] ?? '',
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'originalName': originalName,
      'path': path,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

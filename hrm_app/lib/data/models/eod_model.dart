class EodModel {
  static DateTime _parseDateOnly(String dateString) {
    try {
      DateTime result;

      if (dateString.contains('T')) {
        final datePart = dateString.split('T')[0];
        final dateComponents = datePart.split('-');

        if (dateComponents.length == 3) {
          final year = int.parse(dateComponents[0]);
          final month = int.parse(dateComponents[1]);
          final day = int.parse(dateComponents[2]);

          result = DateTime.utc(year, month, day);
        } else {
          final parsedDate = DateTime.parse(dateString);
          result = DateTime.utc(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
          );
        }
      } else {
        result = DateTime.parse(dateString);
      }

      return result;
    } catch (e) {
      return DateTime.now();
    }
  }

  static DateTime _parseDateTime(String dateTimeString) {
    try {
      final parsedDateTime = DateTime.parse(dateTimeString);
      final localDateTime = parsedDateTime.toLocal();

      return localDateTime;
    } catch (e) {
      return DateTime.now();
    }
  }

  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeEmail;
  final String employeeJobTitle;
  final DateTime date;

  final String? projectName;
  final String? taskDoneToday;
  final String? challengesFaced;
  final String? studentName;
  final String? technology;
  final String? taskType;
  final double? projectStatus;
  final DateTime? deadline;
  final int? daysTaken;
  final bool? reportSent;
  final String? personWorkingOnReport;
  final String? reportStatus;

  final String project;
  final String tasksCompleted;
  final String challenges;
  final String nextDayPlan;
  final DateTime submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  EodModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeEmail,
    required this.employeeJobTitle,
    required this.date,
    this.projectName,
    this.taskDoneToday,
    this.challengesFaced,
    this.studentName,
    this.technology,
    this.taskType,
    this.projectStatus,
    this.deadline,
    this.daysTaken,
    this.reportSent,
    this.personWorkingOnReport,
    this.reportStatus,
    required this.project,
    required this.tasksCompleted,
    required this.challenges,
    required this.nextDayPlan,
    required this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EodModel.fromJson(Map<String, dynamic> json) {
    return EodModel(
      id: json['_id'] ?? '',
      employeeId: json['employee']?['_id'] ?? json['employee'] ?? '',
      employeeName: json['employee']?['name'] ?? 'Unknown Employee',
      employeeEmail: json['employee']?['email'] ?? '',
      employeeJobTitle: json['employee']?['jobTitle'] ?? '',
      date: _parseDateOnly(json['date']),

      projectName: json['projectName'],
      taskDoneToday: json['taskDoneToday'],
      challengesFaced: json['challengesFaced'],
      studentName: json['studentName'],
      technology: json['technology'],
      taskType: json['taskType'],
      projectStatus: json['projectStatus']?.toDouble(),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      daysTaken: json['daysTaken'],
      reportSent: json['reportSent'] is bool
          ? json['reportSent']
          : (json['reportSent'] == 'true' || json['reportSent'] == true),
      personWorkingOnReport: json['personWorkingOnReport'],
      reportStatus: json['reportStatus'],

      project: json['project'] ?? '',
      tasksCompleted: json['tasksCompleted'] ?? '',
      challenges: json['challenges'] ?? '',
      nextDayPlan: json['nextDayPlan'] ?? '',
      submittedAt: _parseDateTime(json['submittedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'employee': {
        '_id': employeeId,
        'name': employeeName,
        'email': employeeEmail,
        'jobTitle': employeeJobTitle,
      },
      'date': date.toIso8601String(),

      'projectName': projectName,
      'taskDoneToday': taskDoneToday,
      'challengesFaced': challengesFaced,
      'studentName': studentName,
      'technology': technology,
      'taskType': taskType,
      'projectStatus': projectStatus,
      'deadline': deadline?.toIso8601String(),
      'daysTaken': daysTaken,
      'reportSent': reportSent,
      'personWorkingOnReport': personWorkingOnReport,
      'reportStatus': reportStatus,

      'project': project,
      'tasksCompleted': tasksCompleted,
      'challenges': challenges,
      'nextDayPlan': nextDayPlan,
      'submittedAt': submittedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EodModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? employeeEmail,
    String? employeeJobTitle,
    DateTime? date,
    String? projectName,
    String? taskDoneToday,
    String? challengesFaced,
    String? studentName,
    String? technology,
    String? taskType,
    double? projectStatus,
    DateTime? deadline,
    int? daysTaken,
    bool? reportSent,
    String? personWorkingOnReport,
    String? reportStatus,
    String? project,
    String? tasksCompleted,
    String? challenges,
    String? nextDayPlan,
    DateTime? submittedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EodModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      employeeJobTitle: employeeJobTitle ?? this.employeeJobTitle,
      date: date ?? this.date,

      projectName: projectName ?? this.projectName,
      taskDoneToday: taskDoneToday ?? this.taskDoneToday,
      challengesFaced: challengesFaced ?? this.challengesFaced,
      studentName: studentName ?? this.studentName,
      technology: technology ?? this.technology,
      taskType: taskType ?? this.taskType,
      projectStatus: projectStatus ?? this.projectStatus,
      deadline: deadline ?? this.deadline,
      daysTaken: daysTaken ?? this.daysTaken,
      reportSent: reportSent ?? this.reportSent,
      personWorkingOnReport:
          personWorkingOnReport ?? this.personWorkingOnReport,
      reportStatus: reportStatus ?? this.reportStatus,

      project: project ?? this.project,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      challenges: challenges ?? this.challenges,
      nextDayPlan: nextDayPlan ?? this.nextDayPlan,
      submittedAt: submittedAt ?? this.submittedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedSubmittedAt {
    final now = DateTime.now();
    final difference = now.difference(submittedAt);

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

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  bool get isThisMonth {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  String get formattedDeadline {
    if (deadline == null) return 'Not set';
    return '${deadline!.day}/${deadline!.month}/${deadline!.year}';
  }

  String get projectStatusDisplay {
    if (projectStatus == null) return 'Not set';
    return '${projectStatus!.toInt()}%';
  }

  String get taskTypeDisplay {
    if (taskType == null) return 'Not set';
    return taskType!;
  }

  String get reportStatusDisplay {
    if (reportStatus == null) return 'Not Applicable';
    return reportStatus!;
  }

  String get reportSentDisplay {
    if (reportSent == null) return 'Not Applicable';
    return reportSent! ? 'Yes' : 'No';
  }
}

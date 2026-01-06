class WebSocketEvents {
  static const String connection = 'connection';
  static const String disconnect = 'disconnect';
  static const String authenticate = 'authenticate';
  static const String authenticated = 'authenticated';
  static const String authenticationFailed = 'authentication_failed';

  static const String joinRoom = 'join_room';
  static const String leaveRoom = 'leave_room';
  static const String roomJoined = 'room_joined';
  static const String roomLeft = 'room_left';

  static const String userConnected = 'user_connected';
  static const String userDisconnected = 'user_disconnected';
  static const String userStatusChanged = 'user_status_changed';

  static const String employeeCreated = 'employee_created';
  static const String employeeUpdated = 'employee_updated';
  static const String employeeDeleted = 'employee_deleted';
  static const String employeeStatusChanged = 'employee_status_changed';
  static const String employeeProfileUpdated = 'employee_profile_updated';

  static const String leaveRequestCreated = 'leave_request_created';
  static const String leaveRequestApproved = 'leave_request_approved';
  static const String leaveRequestRejected = 'leave_request_rejected';
  static const String leaveRequestCancelled = 'leave_request_cancelled';
  static const String leaveBalanceUpdated = 'leave_balance_updated';
  static const String leaveCalendarUpdated = 'leave_calendar_updated';

  static const String payslipRequestCreated = 'payslip_request_created';
  static const String payslipRequestApproved = 'payslip_request_approved';
  static const String payslipRequestRejected = 'payslip_request_rejected';
  static const String payslipGenerated = 'payslip_generated';
  static const String payrollProcessed = 'payroll_processed';
  static const String salaryUpdated = 'salary_updated';

  static const String messageSent = 'message_sent';
  static const String messageReceived = 'message_received';
  static const String messageRead = 'message_read';
  static const String messageDeleted = 'message_deleted';
  static const String conversationCreated = 'conversation_created';
  static const String typingIndicator = 'typing_indicator';
  static const String typingStopped = 'typing_stopped';

  static const String eodSubmitted = 'eod_submitted';
  static const String eodApproved = 'eod_approved';
  static const String eodRejected = 'eod_rejected';
  static const String eodReminder = 'eod_reminder';
  static const String eodDeadlineApproaching = 'eod_deadline_approaching';

  static const String announcementCreated = 'announcement_created';
  static const String announcementUpdated = 'announcement_updated';
  static const String announcementDeleted = 'announcement_deleted';
  static const String notificationSent = 'notification_sent';
  static const String systemAlert = 'system_alert';

  static const String checkIn = 'check_in';
  static const String checkOut = 'check_out';
  static const String breakStart = 'break_start';
  static const String breakEnd = 'break_end';
  static const String overtimeLogged = 'overtime_logged';
  static const String attendanceUpdated = 'attendance_updated';

  static const String customEvent = 'custom_event';

  static const String error = 'error';
  static const String rateLimitExceeded = 'rate_limit_exceeded';
  static const String invalidData = 'invalid_data';

  static const String systemMaintenance = 'system_maintenance';
  static const String systemUpdate = 'system_update';
  static const String connectionStatus = 'connection_status';
  static const String heartbeat = 'heartbeat';
}

class WebSocketRooms {
  static const String adminRoom = 'admin_room';
  static const String hrRoom = 'hr_room';
  static const String employeeRoom = 'employee_room';
  static const String companyWide = 'company_wide';

  static String userRoom(String userId) => 'user_$userId';
  static String departmentRoom(String deptId) => 'department_$deptId';
  static String projectRoom(String projectId) => 'project_$projectId';
  static String teamRoom(String teamId) => 'team_$teamId';
}

class EventCategories {
  static const String connection = 'connection';
  static const String userManagement = 'user_management';
  static const String employeeManagement = 'employee_management';
  static const String leaveManagement = 'leave_management';
  static const String payroll = 'payroll';
  static const String messaging = 'messaging';
  static const String eod = 'eod';
  static const String announcements = 'announcements';
  static const String attendance = 'attendance';
  static const String system = 'system';
}

class EventPriorities {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String critical = 'critical';
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketEventData {
  final String event;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? room;
  final String? userId;

  WebSocketEventData({
    required this.event,
    required this.data,
    required this.timestamp,
    this.room,
    this.userId,
  });

  factory WebSocketEventData.fromMap(Map<String, dynamic> map) {
    return WebSocketEventData(
      event: map['event'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      room: map['room'],
      userId: map['userId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'room': room,
      'userId': userId,
    };
  }
}

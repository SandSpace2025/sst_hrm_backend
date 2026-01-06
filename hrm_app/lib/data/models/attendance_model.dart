class AttendanceRecord {
  final DateTime date;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final String status;
  final bool isLate;
  final bool isEarlyLeave;
  final List<dynamic> sessions;
  final Duration breakDuration;
  final Duration totalWorkDuration;
  final int latePenaltyMinutes;
  final int shortfallPenaltyMinutes;
  final int totalPenaltyMinutes;

  AttendanceRecord({
    required this.date,
    this.clockInTime,
    this.clockOutTime,
    required this.status,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.sessions = const [],
    this.breakDuration = Duration.zero,
    this.totalWorkDuration = Duration.zero,
    this.latePenaltyMinutes = 0,
    this.shortfallPenaltyMinutes = 0,
    this.totalPenaltyMinutes = 0,
  });

  // Helper to get duration
  Duration get workingDuration {
    if (totalWorkDuration > Duration.zero) return totalWorkDuration;
    // Fallback
    if (clockInTime != null && clockOutTime != null) {
      return clockOutTime!.difference(clockInTime!);
    }
    return Duration.zero;
  }
}

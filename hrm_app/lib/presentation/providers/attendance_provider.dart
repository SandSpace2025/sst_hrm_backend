import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/core/services/api_service.dart';
import 'package:hrm_app/data/models/attendance_model.dart';

class AttendanceProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiService _apiService = ApiService();

  bool _isClockedIn = false;
  DateTime? _clockInTime;
  DateTime? _clockOutTime;
  Duration _workedDuration = Duration.zero;
  Duration _breakDuration = Duration.zero;
  List<dynamic> _sessions = [];
  Timer? _timer;
  bool _isLoading = false;

  bool get isClockedIn => _isClockedIn;
  DateTime? get clockInTime => _clockInTime;
  DateTime? get clockOutTime => _clockOutTime;
  Duration get workedDuration => _workedDuration;
  Duration get breakDuration => _breakDuration;
  List<dynamic> get sessions => _sessions;
  bool get isLoading => _isLoading;
  int get livePenaltyMinutes => _livePenaltyMinutes;

  int _livePenaltyMinutes = 0;

  List<AttendanceRecord> _attendanceHistory = [];
  List<AttendanceRecord> get attendanceHistory => _attendanceHistory;

  bool _isDevMode = false;
  bool get isDevMode => _isDevMode;

  AttendanceProvider() {
    loadAttendance();
  }

  Future<void> loadAttendance({int? month, int? year}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _syncWithServer(month: month, year: year);
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncWithServer({int? month, int? year}) async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) return;

    try {
      final response = await _apiService.getAttendanceStatus(token);
      final data = response['data'];

      if (data != null) {
        _sessions = data['sessions'] ?? [];
        _breakDuration = Duration(
          milliseconds: data['totalBreakDuration'] ?? 0,
        );
        _livePenaltyMinutes = data['totalPenaltyMinutes'] ?? 0;

        if (_sessions.isNotEmpty) {
          final lastSession = _sessions.last;
          final firstSession = _sessions.first;

          _clockInTime = DateTime.parse(firstSession['checkInTime']).toLocal();

          if (lastSession['checkOutTime'] == null) {
            _isClockedIn = true;
            _clockOutTime = null;

            int totalPastDuration = 0;
            for (var i = 0; i < _sessions.length - 1; i++) {
              totalPastDuration += (_sessions[i]['duration'] as num? ?? 0)
                  .toInt();
            }
            final currentSessionStart = DateTime.parse(
              lastSession['checkInTime'],
            ).toLocal();
            _workedDuration =
                Duration(milliseconds: totalPastDuration) +
                DateTime.now().difference(currentSessionStart);

            _startTimer();
          } else {
            _isClockedIn = false;
            _clockOutTime = DateTime.parse(
              lastSession['checkOutTime'],
            ).toLocal();
            _workedDuration = Duration(
              milliseconds: data['totalDuration'] ?? 0,
            );
            _stopTimer();
          }
        } else {
          _clockInTime = null;
          _clockOutTime = null;
          _isClockedIn = false;
          _workedDuration = Duration.zero;
          _stopTimer();
        }
      } else {
        _sessions = [];
        _clockInTime = null;
        _clockOutTime = null;
        _isClockedIn = false;
        _workedDuration = Duration.zero;
        _breakDuration = Duration.zero;
        _stopTimer();
      }

      await _fetchHistory(token, month: month, year: year);
    } catch (e) {}
  }

  Future<void> _fetchHistory(String token, {int? month, int? year}) async {
    try {
      final response = await _apiService.getAttendanceHistory(
        token,
        month: month,
        year: year,
      );
      final List<dynamic> historyData = response['data'] ?? [];

      _attendanceHistory = historyData.map((json) {
        return AttendanceRecord(
          date: DateTime.parse(json['date']).toLocal(),
          clockInTime: json['clockInTime'] != null
              ? DateTime.parse(json['clockInTime']).toLocal()
              : null,
          clockOutTime: json['clockOutTime'] != null
              ? DateTime.parse(json['clockOutTime']).toLocal()
              : null,
          status: json['status'] ?? 'Absent',
          sessions: json['sessions'] ?? [],
          breakDuration: Duration(
            milliseconds: json['totalBreakDuration'] ?? 0,
          ),
          totalWorkDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
          latePenaltyMinutes: json['lateArrivalPenaltyMinutes'] ?? 0,
          shortfallPenaltyMinutes: json['shortfallPenaltyMinutes'] ?? 0,
          totalPenaltyMinutes: json['totalPenaltyMinutes'] ?? 0,
        );
      }).toList();
      notifyListeners();
    } catch (e) {}
  }

  Future<void> punchAction({String? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null) {
        throw Exception('Authentication required');
      }

      if (_isClockedIn) {
        await _apiService.punchOut(token);
      } else {
        await _apiService.punchIn(token);
      }

      await _syncWithServer();
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sessions.isNotEmpty && _sessions.last['checkInTime'] != null) {
        int totalPastDuration = 0;
        for (var i = 0; i < _sessions.length - 1; i++) {
          totalPastDuration += (_sessions[i]['duration'] as num? ?? 0).toInt();
        }
        final currentSessionStart = DateTime.parse(
          _sessions.last['checkInTime'],
        ).toLocal();
        _workedDuration =
            Duration(milliseconds: totalPastDuration) +
            DateTime.now().difference(currentSessionStart);
        notifyListeners();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void toggleDevMode() {
    notifyListeners();
  }

  Future<void> getAttendanceForMonth(DateTime date) async {
    await loadAttendance(month: date.month, year: date.year);
  }

  Color getStatusColor(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    if (normalizedDay.isAfter(DateTime.now())) {
      return Colors.transparent;
    }

    final record = _attendanceHistory.firstWhere(
      (r) => DateUtils.isSameDay(r.date, normalizedDay),
      orElse: () => AttendanceRecord(date: day, status: 'Unknown'),
    );

    switch (record.status) {
      case 'Present':
        return const Color(0xFF4CAF50);
      case 'Absent':
        return const Color(0xFFF44336);
      case 'Result':
      case 'Half Day':
        return Colors.lightBlue;
      case 'Leave':
        return const Color(0xFF2196F3);
      case 'Weekend':
        return const Color(0xFF9E9E9E);
      case 'Holiday':
        return const Color(0xFFFFC107);
      case 'Pending':
        if (DateUtils.isSameDay(day, DateTime.now())) {
          return Colors.orange.withValues(alpha: 0.5);
        }
        return Colors.transparent;
      default:
        if (DateUtils.isSameDay(day, DateTime.now())) {
          return Colors.transparent;
        }
        return Colors.transparent;
    }
  }

  void clearData() {
    _stopTimer();
    _isClockedIn = false;
    _clockInTime = null;
    _clockOutTime = null;
    _workedDuration = Duration.zero;
    _breakDuration = Duration.zero;
    _sessions = [];
    _attendanceHistory = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

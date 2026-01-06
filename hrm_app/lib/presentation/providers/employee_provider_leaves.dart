part of 'employee_provider.dart';

extension EmployeeProviderLeaves on EmployeeProvider {
  Future<void> applyForLeave(
    String token,
    String leaveType,
    String durationType,
    DateTime startDate,
    DateTime endDate,
    String reason, {
    String? halfDayPeriod,
    int? permissionHours,
    String? permissionStartTime,
    String? permissionEndTime,
    String? medicalCertificatePath,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isApplyingLeave = true;
    _error = null;
    _notify();

    try {
      final leaveData = {
        'leaveType': leaveType,
        'durationType': durationType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'reason': reason,
      };

      if (durationType == 'half_day' && halfDayPeriod != null) {
        leaveData['halfDayPeriod'] = halfDayPeriod;
      }

      if (durationType == 'hours' && permissionHours != null) {
        leaveData['permissionHours'] = permissionHours.toString();
        if (permissionStartTime != null) {
          leaveData['permissionStartTime'] = permissionStartTime;
        }
        if (permissionEndTime != null) {
          leaveData['permissionEndTime'] = permissionEndTime;
        }
      }

      await _leaveRepository.applyForLeave(authToken, leaveData);

      await Future.wait([
        loadLeaveRequests(authToken),
        loadLeaveBalance(authToken),
        loadLeaveStatistics(authToken),
      ]);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isApplyingLeave = false;
      _notify();
    }
  }

  Future<void> loadLeaveRequests(
    String token, {
    int page = 1,
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _leaveRepository.getLeaveRequests(
        authToken,
        status: status,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        page: page,
      );
      _leaveRequests = response['leaveRequests'] ?? [];
    } catch (e) {
      _error = e.toString();
      _leaveRequests = [];
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadLeaveBalance(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final userId = _getUserId(authToken);
    final role = _userRole ?? 'employee';

    try {
      final cached = await HiveCacheService.getCachedLeaveBalance(
        role,
        userId: userId,
      );
      if (cached != null) {
        _leaveBalance = cached;
        _notify();
      }

      final response = await _leaveRepository.getLeaveBalance(authToken);
      _leaveBalance = response;
      await HiveCacheService.cacheLeaveBalance(role, response, userId: userId);
    } catch (e) {
      if (_leaveBalance == null) {
        _error = e.toString();
      }
    }
    _notify();
  }

  Future<void> loadLeaveStatistics(String token) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      final response = await _leaveRepository.getLeaveStatistics(authToken);
      _leaveStatistics = response;
    } catch (e) {
      _error = e.toString();
    }
    _notify();
  }

  Future<void> loadBlackoutDates(String token, {int? year, int? month}) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    try {
      final response = await _leaveRepository.getBlackoutDates(
        authToken,
        year: year,
        month: month,
      );
      _blackoutDates = response['blackoutDates'] ?? [];
    } catch (e) {
      _error = e.toString();
    }
    _notify();
  }

  Future<void> cancelLeaveRequest(
    String token,
    String leaveRequestId, {
    String? cancellationReason,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      await _leaveRepository.cancelLeaveRequest(
        leaveRequestId,
        authToken,
        cancellationReason: cancellationReason,
      );

      await loadLeaveRequests(authToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }
}

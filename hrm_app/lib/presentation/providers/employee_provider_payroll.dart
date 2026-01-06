part of 'employee_provider.dart';

extension EmployeeProviderPayroll on EmployeeProvider {
  Future<void> loadPayslips(
    String token, {
    int page = 1,
    String? year,
    String? month,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final userId = _getUserId(authToken);

    if (_hasUserIdChanged(userId)) forceRefresh = true;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final role = _userRole ?? 'employee';
      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedPayslips(
          role,
          userId: userId,
        );
        if (cached != null) {
          _payslips = cached;
          _isLoading = false;
          _notify();
          return;
        }
      }

      final payslips = await OptimizedApiService.getPayslips(
        authToken,
        page: page,
        year: year != null ? int.tryParse(year) : null,
        month: month,
      );
      _payslips = payslips;
      await HiveCacheService.cachePayslips(role, _payslips, userId: userId);
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
        final role = _userRole ?? 'employee';
        final cached = await HiveCacheService.getCachedPayslips(
          role,
          userId: userId,
        );
        if (cached != null) {
          _payslips = cached;
          _error = null;
        } else {
          _error = 'No internet connection';
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadCurrentSalary(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final userId = _getUserId(authToken);

    if (_hasUserIdChanged(userId)) forceRefresh = true;

    try {
      final role = _userRole ?? 'employee';
      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedCurrentSalary(
          role,
          userId: userId,
        );
        if (cached != null) {
          _currentSalary = cached;
          _notify();
          return;
        }
      }

      final payslips = await OptimizedApiService.getPayslips(authToken);

      if (payslips.isNotEmpty) {
        final latestPayslip = payslips.first;

        // Extract nested fields safely
        final calculatedFields = latestPayslip['calculatedFields'] ?? {};
        final deductions = latestPayslip['deductions'] ?? {};
        final payslipDetails = latestPayslip['payslipDetails'] ?? {};

        _currentSalary = {
          'netSalary': latestPayslip['totalPay'] ?? 0,
          'bonus': latestPayslip['bonus'] ?? 0,
          'payPeriod': latestPayslip['payPeriod'],
          'basicPay': calculatedFields['basicPay'] ?? 0,
          'penalty': deductions['penalty'] ?? 0,
          'lopDays': payslipDetails['lopDays'] ?? 0,
          'hasData': true,
        };
      } else {
        _currentSalary = {
          'netSalary': 0,
          'bonus': 0,
          'payPeriod': null,
          'basicPay': 0,
          'penalty': 0,
          'lopDays': 0,
          'hasData': false,
        };
      }
      await HiveCacheService.cacheCurrentSalary(
        role,
        _currentSalary!,
        userId: userId,
      );
      _error = null;
    } catch (e) {
      final role = _userRole ?? 'employee';
      final cached = await HiveCacheService.getCachedCurrentSalary(
        role,
        userId: userId,
      );
      if (cached != null) {
        _currentSalary = cached;
      } else {
        _currentSalary = {
          'netSalary': 0,
          'bonus': 0,
          'payPeriod': null,
          'basicPay': 0,
          'penalty': 0,
          'lopDays': 0,
          'hasData': false,
        };
        _error = e.toString();
      }
    }
    _notify();
  }

  Future<void> loadSalaryBreakdown(String token, String month, int year) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      // 1. Try to get actual payslip first
      final payslips = await OptimizedApiService.getPayslips(
        token,
        month: month,
        year: year,
      );

      if (payslips.isNotEmpty) {
        final payslip = payslips.first;
        final calculatedFields = payslip['calculatedFields'] ?? {};
        final deductions = payslip['deductions'] ?? {};
        final payslipDetails = payslip['payslipDetails'] ?? {};

        _salaryBreakdown = {
          'netSalary': payslip['totalPay'] ?? 0,
          'basicPay': calculatedFields['basicPay'] ?? 0,
          'penalty': deductions['penalty'] ?? 0,
          'pf': deductions['pf'] ?? 0,
          'esi': deductions['esi'] ?? 0,
          'pt': deductions['pt'] ?? 0,
          'lopDays': payslipDetails['lopDays'] ?? 0,
          'hasData': true,
          'isPreview': false,
        };
      } else {
        // 2. If no payslip, fetch preview based on attendance
        final previewData = await OptimizedApiService.getSalaryBreakdownPreview(
          token,
          month: month,
          year: year,
        );

        if (previewData['hasData'] == true) {
          _salaryBreakdown = {
            'netSalary': previewData['netSalary'] ?? 0,
            'basicPay': previewData['basicPay'] ?? 0,
            'penalty': previewData['penalty'] ?? 0,
            'pf': previewData['pf'] ?? 0,
            'esi': previewData['esi'] ?? 0,
            'pt': previewData['pt'] ?? 0,
            'lopDays': previewData['lopDays'] ?? 0,
            'hasData': true,
            'isPreview': true,
          };
        } else {
          _salaryBreakdown = {
            'netSalary': 0,
            'basicPay': 0,
            'penalty': 0,
            'pf': 0,
            'esi': 0,
            'pt': 0,
            'lopDays': 0,
            'hasData': false,
            'isPreview': false,
            'message': previewData['message'],
          };
        }
      }
    } catch (e) {
      _salaryBreakdown = {
        'netSalary': 0,
        'basicPay': 0,
        'penalty': 0,
        'lopDays': 0,
        'hasData': false,
      };
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> submitPayslipRequest(
    String token,
    String startMonth,
    String startYear,
    String endMonth,
    String endYear,
    String reason,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      await _payrollRepository.submitPayslipRequest(authToken, {
        'startMonth': startMonth,
        'startYear': startYear,
        'endMonth': endMonth,
        'endYear': endYear,
        'reason': reason,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadPayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    if (!forceRefresh && _isLoading) return;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final requests = await OptimizedApiService.getPayslipRequests(authToken);

      if (requests.isNotEmpty) {
        _payslipRequests = requests;
      } else {
        _payslipRequests = [];
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> refreshPayslipRequests(String token) async {
    await loadPayslipRequests(token, forceRefresh: true);
  }

  Future<void> requestPayslip(
    String token,
    String month,
    String year,
    String reason,
  ) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      await _payrollRepository.submitPayslipRequest(token, {
        'startMonth': month,
        'startYear': year,
        'endMonth': month,
        'endYear': year,
        'reason': reason,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> downloadPayslip(String token, String payslipId) async {
    try {
      await _payrollRepository.downloadPayslip(token, payslipId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }
}

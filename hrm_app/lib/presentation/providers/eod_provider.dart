import 'package:flutter/material.dart';
import 'package:hrm_app/core/services/optimized_api_service.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';

class EODProvider with ChangeNotifier {
  Map<String, dynamic>? _todayEOD;
  Map<String, dynamic>? get todayEOD => _todayEOD;

  List<dynamic> _eodEntries = [];
  List<dynamic> get eodEntries => _eodEntries;

  List<dynamic> _myEODs = [];
  List<dynamic> get myEODs => _myEODs;

  Map<String, dynamic>? _eodStats;
  Map<String, dynamic>? get eodStats => _eodStats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _error;
  String? get error => _error;

  bool _canSubmit = true;
  bool get canSubmit => _canSubmit;

  String? _timeRestriction;
  String? get timeRestriction => _timeRestriction;

  bool get canSubmitToday => _canSubmit && !isBeforeSubmissionTime;

  Future<void> _refreshDashboard(BuildContext? context) async {
    if (context != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final employeeProvider = Provider.of<EmployeeProvider>(
          context,
          listen: false,
        );

        if (authProvider.token != null) {
          await OptimizedApiService.clearCache('dashboard', 'employee');

          await employeeProvider.refreshDashboardData(authProvider.token!);
        }
      } catch (e) {}
    }
  }

  bool get isBeforeSubmissionTime {
    return false;
  }

  String? get timeRestrictionMessage {
    return _timeRestriction;
  }

  Future<void> loadTodayEOD(String token) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await OptimizedApiService.getTodayEOD(token);

      if (response['eod'] != null) {
        _todayEOD = response['eod'];
        _canSubmit = false;
      } else {
        _canSubmit = true;
        _timeRestriction = response['message'];
        _todayEOD = null;
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('no eod submitted') ||
          errorMessage.contains('not found') ||
          errorMessage.contains('404')) {
        _canSubmit = true;
        _todayEOD = null;
        _timeRestriction = null;
        _clearError();
      } else if (errorMessage.contains('connection') ||
          errorMessage.contains('socket') ||
          errorMessage.contains('network')) {
        _setError(
          'Network connection error. Please check your internet connection and try again.',
        );
        _canSubmit = true;
        _todayEOD = null;
        _timeRestriction = null;
      } else {
        _setError(e.toString());
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> submitEOD(
    String token,
    Map<String, dynamic> eodData, {
    BuildContext? context,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      final enhancedEodData = {
        ...eodData,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'submittedAt': DateTime.now().toIso8601String(),
      };

      if (_todayEOD != null) {
        await OptimizedApiService.updateEOD(
          token,
          _todayEOD!['_id'],
          enhancedEodData,
        );
      } else {
        await OptimizedApiService.submitEOD(token, enhancedEodData);
      }

      await loadTodayEOD(token);

      await _refreshDashboard(context);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setSubmitting(false);
    }
  }

  Future<bool> createEOD(
    String token,
    Map<String, dynamic> eodData, {
    BuildContext? context,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      final enhancedEodData = {
        ...eodData,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'submittedAt': DateTime.now().toIso8601String(),
      };

      await OptimizedApiService.submitEOD(token, enhancedEodData);
      await loadTodayEOD(token);

      await _refreshDashboard(context);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<bool> updateEOD(
    String token,
    String eodId,
    Map<String, dynamic> eodData, {
    BuildContext? context,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      final enhancedEodData = {
        ...eodData,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await OptimizedApiService.updateEOD(token, eodId, enhancedEodData);
      await loadTodayEOD(token);

      await _refreshDashboard(context);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  Future<void> loadEODEntries(
    String token, {
    int page = 1,
    String? startDate,
    String? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await OptimizedApiService.getEODEntries(
        token,
        startDate: startDate,
        endDate: endDate,
      );
      _eodEntries = response['eods'] ?? [];
    } catch (e) {
      _setError(e.toString());
      _eodEntries = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyEODs(
    String token, {
    int page = 1,
    String? startDate,
    String? endDate,
  }) async {
    await loadEODEntries(
      token,
      page: page,
      startDate: startDate,
      endDate: endDate,
    );
    _myEODs = _eodEntries;
  }

  Future<void> loadEODStats(String token) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await OptimizedApiService.getEODStats(token);
      _eodStats = response;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteEOD(
    String token,
    String eodId, {
    BuildContext? context,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      await OptimizedApiService.deleteEOD(token, eodId);

      await loadTodayEOD(token);

      await _refreshDashboard(context);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  void clearData() {
    _todayEOD = null;
    _eodEntries = [];
    _myEODs = [];
    _eodStats = null;
    _error = null;
    _canSubmit = true;
    _timeRestriction = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSubmitting(bool submitting) {
    _isSubmitting = submitting;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

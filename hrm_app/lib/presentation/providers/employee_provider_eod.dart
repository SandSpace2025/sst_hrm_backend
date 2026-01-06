part of 'employee_provider.dart';

extension EmployeeProviderEOD on EmployeeProvider {
  Future<void> submitEOD(
    String token,
    String workDescription,
    String challenges,
    String tomorrowPlan,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isSubmittingEOD = true;
    _error = null;
    _notify();

    try {
      await _employeeRepository.submitEOD(authToken, {
        'workDescription': workDescription,
        'challenges': challenges,
        'tomorrowPlan': tomorrowPlan,
      });
      await loadEODEntries(authToken);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isSubmittingEOD = false;
      _notify();
    }
  }

  Future<void> loadEODEntries(String token, {int page = 1}) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _employeeRepository.getEODEntries(
        authToken,
        page: page,
      );
      if (response.containsKey('entries')) {
        _eodEntries = response['entries'] ?? [];
      } else if (response.containsKey('eods')) {
        _eodEntries = response['eods'] ?? [];
      } else if (response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          _eodEntries = data;
        } else if (data is Map && data.containsKey('entries')) {
          _eodEntries = data['entries'];
        }
      } else {
        _eodEntries = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notify();
    }
  }
}

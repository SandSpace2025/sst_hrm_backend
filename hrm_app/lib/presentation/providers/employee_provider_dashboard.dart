part of 'employee_provider.dart';

extension EmployeeProviderDashboard on EmployeeProvider {
  Future<void> fetchEmployeeDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final userId = _getUserId(authToken);

    if (_hasUserIdChanged(userId)) {
      forceRefresh = true;
    }

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final response = await _employeeRepository.getDashboardSummary(
        authToken,
        forceRefresh: forceRefresh,
      );

      _dashboardData = response;
      _dashboardLoadedFromCache = false;
      _error = null;
      final unreadSenderIds = _dashboardData?['unreadSenderIds'];
      if (unreadSenderIds is List) {
        setUnreadConversations(unreadSenderIds);
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
        final role = _userRole ?? 'employee';
        final cached = await HiveCacheService.getCachedDashboard(
          role,
          userId: userId,
        );
        if (cached != null) {
          _dashboardData = cached;
          _dashboardLoadedFromCache = true;
          _error = null;
        } else {
          _error = 'No internet connection and no cached data';
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadEmployeeProfile(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final userId = _getUserId(authToken);

    if (_hasUserIdChanged(userId)) {
      forceRefresh = true;
    }

    try {
      if (forceRefresh) {
        final response = await _employeeRepository.getProfile(
          authToken,
          forceRefresh: true,
        );

        _employeeProfile = Employee.fromJson(response);
        _profileLoadedFromCache = false;
        _error = null;
      } else {
        final role = _userRole ?? 'employee';
        final cached = await HiveCacheService.getCachedProfile(
          role,
          userId: userId,
        );
        if (cached != null) {
          _employeeProfile = Employee.fromJson(
            _convertToMapStringDynamic(cached),
          );
          _profileLoadedFromCache = true;
          _error = null;
        } else {
          final response = await _employeeRepository.getProfile(authToken);
          _employeeProfile = Employee.fromJson(response);
          _profileLoadedFromCache = false;
          _error = null;
        }
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('SocketException')) {
        final role = _userRole ?? 'employee';
        final cached = await HiveCacheService.getCachedProfile(
          role,
          userId: userId,
        );
        if (cached != null) {
          _employeeProfile = Employee.fromJson(
            _convertToMapStringDynamic(cached),
          );
          _profileLoadedFromCache = true;
          _error = null;
        } else {
          _error = 'No internet connection and no cached profile';
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _notify();
    }
  }

  Future<void> updateEmployeeProfile(
    Map<String, dynamic> updateData,
    String token,
  ) async {
    await _ensureAuth();
    final authToken = _token ?? token;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      await _employeeRepository.updateProfile(updateData, authToken);
      await loadEmployeeProfile(authToken, forceRefresh: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void updateEmployeeProfilePic(String imageUrl) {
    if (_employeeProfile != null) {
      _employeeProfile = Employee(
        id: _employeeProfile!.id,
        name: _employeeProfile!.name,
        email: _employeeProfile!.email,
        phone: _employeeProfile!.phone,
        subOrganisation: _employeeProfile!.subOrganisation,
        profilePic: imageUrl,
        employeeId: _employeeProfile!.employeeId,
        jobTitle: _employeeProfile!.jobTitle,
        bloodGroup: _employeeProfile!.bloodGroup,
        user: _employeeProfile!.user,
      );
      _notify();
    }
  }
}

part of 'employee_provider.dart';

extension EmployeeProviderAnnouncements on EmployeeProvider {
  Future<void> loadAnnouncements(
    String token, {
    bool forceRefresh = false,
  }) async {
    await _ensureAuth();
    final authToken = _token ?? token;
    final role = _userRole ?? 'employee';

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          connectivity.any((result) => result != ConnectivityResult.none);

      if (!isOnline) {
        final cached = await HiveCacheService.getCachedAnnouncements(role);
        if (cached != null && cached.isNotEmpty) {
          _announcements = cached;
        } else {
          if (_announcements.isEmpty) _announcements = [];
        }
        _notify();
        return;
      }

      if (!forceRefresh) {
        final cached = await HiveCacheService.getCachedAnnouncements(role);
        if (cached != null && cached.isNotEmpty) {
          _announcements = cached;
          _notify();
          return;
        }
      }

      try {
        final response = await _announcementRepository.getAnnouncements(
          authToken,
          audience: role,
        );

        _announcements = response['announcements'] ?? [];

        await HiveCacheService.cacheAnnouncements(role, _announcements);
        _error = null;
        _notify();
      } on SocketException {
        final cached = await HiveCacheService.getCachedAnnouncements(role);
        if (cached != null) {
          _announcements = cached;
        }
        _notify();
      } catch (e) {
        final cached = await HiveCacheService.getCachedAnnouncements(role);
        if (cached != null) {
          _announcements = cached;
        }
        _notify();
      }
    } catch (e) {
      _notify();
    }
  }
}

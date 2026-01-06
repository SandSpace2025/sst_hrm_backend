import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/services/http_service.dart';

class EmployeeRepository {
  final HttpService _httpService;

  EmployeeRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> getDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedDashboard(
      'employee',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/employee/dashboard-summary',
      token: token,
      contextName: 'Employee Dashboard',
    );

    await HiveCacheService.cacheDashboard('employee', response);

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedProfile(
      'employee',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/employee/profile',
      token: token,
      contextName: 'Get Profile API',
    );

    await HiveCacheService.cacheProfile('employee', response);

    return response as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> data, String token) async {
    await _httpService.put(
      '/api/employee/profile',
      token: token,
      body: data,
      isVoid: true,
      contextName: 'Update Profile API',
    );
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
    String token,
  ) async {
    final body = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
    await _httpService.put(
      '/api/user/password',
      token: token,
      body: body,
      isVoid: true,
      contextName: 'Change Password API',
    );
  }

  Future<Map<String, dynamic>> submitEOD(
    String token,
    Map<String, dynamic> eodData,
  ) async {
    final response = await _httpService.post(
      '/api/eod/create',
      token: token,
      body: eodData,
      expectedStatusCode: 201,
      contextName: 'Submit EOD',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTodayEOD(String token) async {
    final response = await _httpService.get(
      '/api/eod/today',
      token: token,
      contextName: 'Get Today EOD',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEODEntries(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _httpService.get(
      '/api/eod/my-eods',
      token: token,
      queryParams: {'page': page, 'limit': limit},
      contextName: 'My EOD Entries',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEOD(
    String token,
    String eodId,
    Map<String, dynamic> eodData,
  ) async {
    final response = await _httpService.put(
      '/api/eod/$eodId',
      token: token,
      body: eodData,
      contextName: 'Update EOD',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteEOD(String token, String eodId) async {
    await _httpService.delete(
      '/api/eod/$eodId',
      token: token,
      isVoid: true,
      contextName: 'Delete EOD',
    );
  }

  Future<Map<String, dynamic>> getEODStats(String token) async {
    final response = await _httpService.get(
      '/api/eod/stats',
      token: token,
      contextName: 'EOD Stats',
    );
    return response as Map<String, dynamic>;
  }
}

import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/services/http_service.dart';

class HRRepository {
  final HttpService _httpService;

  HRRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> getDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedDashboard(
      'hr',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/hr/dashboard-summary',
      token: token,
      contextName: 'HR Dashboard',
    );

    await HiveCacheService.cacheDashboard('hr', response);

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedProfile(
      'hr',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/hr/profile',
      token: token,
      contextName: 'HR Profile',
    );

    await HiveCacheService.cacheProfile('hr', response);

    return response as Map<String, dynamic>;
  }

  Future<void> updateProfile(Map<String, dynamic> data, String token) async {
    await _httpService.put(
      '/api/hr/profile',
      token: token,
      body: data,
      isVoid: true,
      contextName: 'Update HR Profile',
    );
  }

  Future<Map<String, dynamic>> getEmployees(
    String token, {
    String? search,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _httpService.get(
      '/api/hr/employees',
      token: token,
      queryParams: queryParams,
      contextName: 'Get HR Employees',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> createEmployee(
    String name,
    String email,
    String password,
    String subOrganisation,
    String employeeId,
    String token, {
    String? jobTitle,
    String? phone,
    String? bloodGroup,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'password': password,
      'subOrganisation': subOrganisation,
      'employeeId': employeeId,
    };
    if (jobTitle != null) body['jobTitle'] = jobTitle;
    if (phone != null) body['phone'] = phone;
    if (bloodGroup != null) body['bloodGroup'] = bloodGroup;

    await _httpService.post(
      '/api/hr/employees',
      token: token,
      body: body,
      expectedStatusCode: 201,
      isVoid: true,
      contextName: 'Create Employee',
    );
  }

  Future<void> updateEmployee(
    String employeeId,
    Map<String, dynamic> data,
    String token,
  ) async {
    await _httpService.put(
      '/api/hr/employees/$employeeId',
      token: token,
      body: data,
      isVoid: true,
      contextName: 'Update Employee',
    );
  }

  Future<void> deleteEmployee(String employeeId, String token) async {
    await _httpService.delete(
      '/api/hr/employees/$employeeId',
      token: token,
      isVoid: true,
      contextName: 'Delete Employee',
    );
  }

  Future<Map<String, dynamic>> getEmployeeLeaveData(
    String token,
    String employeeId,
  ) async {
    final response = await _httpService.get(
      '/api/hr/employees/$employeeId/leave-data',
      token: token,
      contextName: 'Get Employee Leave Data',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> updateEmployeeLeaveData(
    String token,
    String employeeId,
    Map<String, dynamic> leaveData,
  ) async {
    await _httpService.put(
      '/api/hr/employees/$employeeId/leave-data',
      token: token,
      body: leaveData,
      isVoid: true,
      contextName: 'Update Employee Leave Data',
    );
  }
}

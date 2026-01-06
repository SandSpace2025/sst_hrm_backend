import 'package:hrm_app/core/services/hive_cache_service.dart';
import 'package:hrm_app/core/services/http_service.dart';

class AdminRepository {
  final HttpService _httpService;

  AdminRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> getDashboardSummary(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedDashboard(
      'admin',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/admin/dashboard-summary',
      token: token,
      contextName: 'Admin Dashboard',
    );

    await HiveCacheService.cacheDashboard('admin', response);

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProfile(
    String token, {
    bool forceRefresh = false,
  }) async {
    final cachedData = await HiveCacheService.getCachedProfile(
      'admin',
      forceRefresh: forceRefresh,
    );
    if (cachedData != null) return cachedData;

    final response = await _httpService.get(
      '/api/user/profile',
      token: token,
      contextName: 'Admin Profile',
    );

    await HiveCacheService.cacheProfile('admin', response);

    return response as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUsersByRole(String role, String token) async {
    final response = await _httpService.get(
      '/api/admin/users/$role',
      token: token,
      contextName: 'Get Users API',
    );
    return response as List<dynamic>;
  }

  Future<void> createUser(
    String name,
    String email,
    String password,
    String role,
    String token, {
    String? subOrganisation,
    String? employeeId,
    String? jobTitle,
    String? bloodGroup,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    };
    if (subOrganisation != null) body['subOrganisation'] = subOrganisation;
    if (employeeId != null) body['employeeId'] = employeeId;
    if (jobTitle != null) body['jobTitle'] = jobTitle;
    if (bloodGroup != null) body['bloodGroup'] = bloodGroup;

    await _httpService.post(
      '/api/admin/create-user',
      token: token,
      body: body,
      expectedStatusCode: 201,
      isVoid: true,
      contextName: 'Create User API',
    );
  }

  Future<void> updateUser(
    String userId,
    Map<String, dynamic> data,
    String token,
  ) async {
    await _httpService.put(
      '/api/admin/users/$userId',
      token: token,
      body: data,
      isVoid: true,
      contextName: 'Update User API',
    );
  }

  Future<void> deleteUser(String userId, String token) async {
    await _httpService.delete(
      '/api/admin/users/$userId',
      token: token,
      isVoid: true,
      contextName: 'Delete User API',
    );
  }

  Future<Map<String, dynamic>> getMessagingPermissionRequests(
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/messaging-permissions/requests',
      token: token,
      contextName: 'Permission Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> grantMessagingPermission(
    String token,
    String employeeId, {
    int durationHours = 48,
  }) async {
    await _httpService.post(
      '/api/messaging-permissions/grant/$employeeId',
      token: token,
      body: {'durationHours': durationHours},
      expectedStatusCode: 200,
      isVoid: true,
      contextName: 'Grant Permission',
    );
  }

  Future<void> revokeMessagingPermission(
    String token,
    String employeeId,
  ) async {
    await _httpService.post(
      '/api/messaging-permissions/revoke/$employeeId',
      token: token,
      expectedStatusCode: 200,
      isVoid: true,
      contextName: 'Revoke Permission',
    );
  }

  Future<Map<String, dynamic>> getActiveMessagingPermissions(
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/messaging-permissions/active',
      token: token,
      contextName: 'Active Permissions',
    );
    return response as Map<String, dynamic>;
  }
}

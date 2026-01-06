import 'package:hrm_app/core/services/http_service.dart';

class LeaveRepository {
  final HttpService _httpService;

  LeaveRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<Map<String, dynamic>> getLeaveRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    String? leaveType,
    String? employeeId,
    String? startDate,
    String? endDate,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (status != null) queryParams['status'] = status;
    if (leaveType != null) queryParams['leaveType'] = leaveType;
    if (employeeId != null) queryParams['employeeId'] = employeeId;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final response = await _httpService.get(
      '/api/leave-requests',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Leave Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestStats(String token) async {
    final response = await _httpService.get(
      '/api/leave-requests/stats',
      token: token,
      contextName: 'Leave Request Stats',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveCalendar(
    String token, {
    int? month,
    int? year,
  }) async {
    final queryParams = <String, dynamic>{};
    if (month != null) queryParams['month'] = month;
    if (year != null) queryParams['year'] = year;

    final response = await _httpService.get(
      '/api/leave-requests/calendar',
      token: token,
      queryParams: queryParams,
      contextName: 'Leave Calendar',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestsByEmployee(
    String employeeId,
    String token, {
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    final response = await _httpService.get(
      '/api/leave-requests/employee/$employeeId',
      token: token,
      queryParams: queryParams,
      contextName: 'Employee Leave Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveRequestById(
    String leaveRequestId,
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/leave-requests/$leaveRequestId',
      token: token,
      contextName: 'Get Leave Request',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateLeaveRequestStatus(
    String leaveRequestId,
    String status,
    String token, {
    String? adminComments,
  }) async {
    final body = {'status': status};
    if (adminComments != null) body['adminComments'] = adminComments;

    final response = await _httpService.put(
      '/api/leave-requests/$leaveRequestId/status',
      token: token,
      body: body,
      contextName: 'Update Leave Status',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bulkUpdateLeaveRequests(
    List<String> leaveRequestIds,
    String status,
    String token, {
    String? adminComments,
  }) async {
    final body = {'leaveRequestIds': leaveRequestIds, 'status': status};
    if (adminComments != null) body['adminComments'] = adminComments;

    final response = await _httpService.put(
      '/api/leave-requests/bulk-update',
      token: token,
      body: body,
      contextName: 'Bulk Update Leave',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteLeaveRequest(String leaveRequestId, String token) async {
    await _httpService.delete(
      '/api/leave-requests/$leaveRequestId',
      token: token,
      isVoid: true,
      contextName: 'Delete Leave Request',
    );
  }

  Future<Map<String, dynamic>> applyForLeave(
    String token,
    Map<String, dynamic> leaveData,
  ) async {
    final response = await _httpService.post(
      '/api/leave/apply',
      token: token,
      body: leaveData,
      expectedStatusCode: 201,
      contextName: 'Apply For Leave',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMyLeaveRequests(
    String token, {
    String? status,
    String? leaveType,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) queryParams['status'] = status;
    if (leaveType != null) queryParams['leaveType'] = leaveType;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final response = await _httpService.get(
      '/api/leave/my-requests',
      token: token,
      queryParams: queryParams,
      contextName: 'My Leave Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveBalance(String token) async {
    final response = await _httpService.get(
      '/api/leave/balance',
      token: token,
      contextName: 'Leave Balance',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLeaveStatistics(String token) async {
    final response = await _httpService.get(
      '/api/leave/statistics',
      token: token,
      contextName: 'Employee Leave Statistics',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBlackoutDates(
    String token, {
    int? year,
    int? month,
  }) async {
    final queryParams = <String, dynamic>{};
    if (year != null) queryParams['year'] = year;
    if (month != null) queryParams['month'] = month;

    final response = await _httpService.get(
      '/api/leave/blackout-dates',
      token: token,
      queryParams: queryParams,
      contextName: 'Blackout Dates',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelLeaveRequest(
    String leaveRequestId,
    String token, {
    String? cancellationReason,
  }) async {
    final body = <String, dynamic>{};
    if (cancellationReason != null) {
      body['cancellationReason'] = cancellationReason;
    }

    final response = await _httpService.put(
      '/api/leave/$leaveRequestId/cancel',
      token: token,
      body: body,
      contextName: 'Cancel Leave Request',
    );
    return response as Map<String, dynamic>;
  }
}

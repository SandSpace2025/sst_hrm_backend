import 'dart:io';
import 'package:hrm_app/core/services/http_service.dart';

class PayrollRepository {
  final HttpService _httpService;

  PayrollRepository({HttpService? httpService})
    : _httpService = httpService ?? HttpService();

  Future<List<dynamic>> getPayrollsForEmployee(
    String employeeId,
    String token,
  ) async {
    final response = await _httpService.get(
      '/api/payroll/employee/$employeeId',
      token: token,
      contextName: 'Get Payrolls',
    );
    return response as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPayroll(
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _httpService.post(
      '/api/payroll',
      token: token,
      body: data,
      expectedStatusCode: 201,
      contextName: 'Create Payroll',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePayroll(
    String payrollId,
    Map<String, dynamic> data,
    String token,
  ) async {
    final response = await _httpService.put(
      '/api/payroll/$payrollId',
      token: token,
      body: data,
      contextName: 'Update Payroll',
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deletePayroll(String payrollId, String token) async {
    await _httpService.delete(
      '/api/payroll/$payrollId',
      token: token,
      isVoid: true,
      contextName: 'Delete Payroll',
    );
  }

  Future<Map<String, dynamic>> getHRPayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _httpService.get(
      '/api/payslip-requests/hr',
      token: token,
      queryParams: queryParams,
      contextName: 'Get HR Payslip Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePayslipRequestStatus(
    String token,
    String requestId,
    Map<String, dynamic> statusData,
  ) async {
    final response = await _httpService.put(
      '/api/payslip-requests/$requestId/status',
      token: token,
      body: statusData,
      contextName: 'Update Payslip Status',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayslipRequestStats(String token) async {
    final response = await _httpService.get(
      '/api/payslip-requests/hr/stats',
      token: token,
      contextName: 'Payslip Request Stats',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayslipApprovalHistory(
    String token, {
    int page = 1,
    int limit = 20,
    String? employeeName,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (employeeName != null) {
      queryParams['employeeName'] = employeeName;
    }

    final response = await _httpService.get(
      '/api/payslip-requests/hr/history',
      token: token,
      queryParams: queryParams,
      contextName: 'Payslip Approval History',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processPayslipWithBasePay(
    String token,
    String requestId,
    Map<String, dynamic> payrollData,
  ) async {
    if (requestId.trim().isEmpty) {
      throw Exception('Invalid payslip request ID');
    }

    final response = await _httpService.post(
      '/api/payslip-requests/${requestId.trim()}/process',
      token: token,
      body: payrollData,
      contextName: 'Process Payslip',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayslips(
    String token, {
    String? year,
    String? month,
    int page = 1,
    int limit = 100,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (year != null) queryParams['year'] = year;
    if (month != null) queryParams['month'] = month;

    final response = await _httpService.get(
      '/api/payslips',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Payslips',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitPayslipRequest(
    String token,
    Map<String, dynamic> requestData,
  ) async {
    final response = await _httpService.post(
      '/api/payslip-requests/submit',
      token: token,
      body: requestData,
      expectedStatusCode: 201,
      contextName: 'Submit Payslip Request',
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployeePayslipRequests(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) queryParams['status'] = status;

    final response = await _httpService.get(
      '/api/payslip-requests/employee',
      token: token,
      queryParams: queryParams,
      contextName: 'Get Employee Payslip Requests',
    );
    return response as Map<String, dynamic>;
  }

  Future<File> downloadPayslip(String token, String payslipId) async {
    final response = await _httpService.download(
      '/api/payslip/download/$payslipId',
      token: token,
      contextName: 'Download Payslip',
    );
    return response;
  }
}

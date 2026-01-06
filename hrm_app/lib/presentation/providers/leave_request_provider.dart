import 'package:flutter/foundation.dart';
import 'package:hrm_app/core/services/api_service.dart';
import 'package:hrm_app/data/models/leave_request_model.dart';

class LeaveRequestProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<LeaveRequestModel> _leaveRequests = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String? _selectedStatus;
  String? _selectedLeaveType;
  String? _selectedEmployeeId;
  Map<String, dynamic>? _stats;

  List<LeaveRequestModel> get leaveRequests => _leaveRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  String? get selectedStatus => _selectedStatus;
  String? get selectedLeaveType => _selectedLeaveType;
  String? get selectedEmployeeId => _selectedEmployeeId;
  Map<String, dynamic>? get stats => _stats;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setFilters({String? status, String? leaveType, String? employeeId}) {
    _selectedStatus = status;
    _selectedLeaveType = leaveType;
    _selectedEmployeeId = employeeId;
    notifyListeners();
  }

  void clearFilters() {
    _selectedStatus = null;
    _selectedLeaveType = null;
    _selectedEmployeeId = null;
    notifyListeners();
  }

  Future<void> loadLeaveRequests(String token, {bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _leaveRequests.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getLeaveRequests(
        token,
        page: _currentPage,
        limit: 10,
        status: _selectedStatus,
        leaveType: _selectedLeaveType,
        employeeId: _selectedEmployeeId,
      );

      final List<dynamic> leaveRequestsData = response['leaveRequests'] ?? [];
      final List<LeaveRequestModel> newLeaveRequests = leaveRequestsData
          .map((data) => LeaveRequestModel.fromJson(data))
          .toList();

      if (refresh) {
        _leaveRequests = newLeaveRequests;
      } else {
        _leaveRequests.addAll(newLeaveRequests);
      }

      final pagination = response['pagination'];
      _hasMoreData = _currentPage < (pagination['totalPages'] ?? 1);
      _currentPage++;

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaveRequestStats(String token) async {
    try {
      final response = await _apiService.getLeaveRequestStats(token);
      _stats = response;
      notifyListeners();
    } catch (e) {}
  }

  Future<bool> updateLeaveRequestStatus(
    String leaveRequestId,
    String status,
    String token, {
    String? adminComments,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateLeaveRequestStatus(
        leaveRequestId,
        status,
        token,
        adminComments: adminComments,
      );

      final updatedLeaveRequest = LeaveRequestModel.fromJson(
        response['leaveRequest'],
      );

      final index = _leaveRequests.indexWhere(
        (leaveRequest) => leaveRequest.id == leaveRequestId,
      );
      if (index != -1) {
        _leaveRequests[index] = updatedLeaveRequest;
      }

      await loadLeaveRequestStats(token);

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> bulkUpdateLeaveRequests(
    List<String> leaveRequestIds,
    String status,
    String token, {
    String? adminComments,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.bulkUpdateLeaveRequests(
        leaveRequestIds,
        status,
        token,
        adminComments: adminComments,
      );

      await loadLeaveRequests(token, refresh: true);

      await loadLeaveRequestStats(token);

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LeaveRequestModel?> getLeaveRequestById(
    String leaveRequestId,
    String token,
  ) async {
    try {
      final response = await _apiService.getLeaveRequestById(
        leaveRequestId,
        token,
      );
      return LeaveRequestModel.fromJson(response['leaveRequest']);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteLeaveRequest(String leaveRequestId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteLeaveRequest(leaveRequestId, token);

      _leaveRequests.removeWhere(
        (leaveRequest) => leaveRequest.id == leaveRequestId,
      );

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaveRequestsByEmployee(
    String employeeId,
    String token, {
    bool refresh = false,
  }) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _leaveRequests.clear();
      _hasMoreData = true;
    }

    if (!_hasMoreData) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getLeaveRequestsByEmployee(
        employeeId,
        token,
        page: _currentPage,
        limit: 10,
      );

      final List<dynamic> leaveRequestsData = response['leaveRequests'] ?? [];
      final List<LeaveRequestModel> newLeaveRequests = leaveRequestsData
          .map((data) => LeaveRequestModel.fromJson(data))
          .toList();

      if (refresh) {
        _leaveRequests = newLeaveRequests;
      } else {
        _leaveRequests.addAll(newLeaveRequests);
      }

      final pagination = response['pagination'];
      _hasMoreData = _currentPage < (pagination['totalPages'] ?? 1);
      _currentPage++;

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<LeaveRequestModel>> getLeaveCalendar(
    String token, {
    int? month,
    int? year,
  }) async {
    try {
      final response = await _apiService.getLeaveCalendar(
        token,
        month: month,
        year: year,
      );

      final List<dynamic> leaveRequestsData = response['leaveRequests'] ?? [];
      return leaveRequestsData
          .map((data) => LeaveRequestModel.fromJson(data))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> refreshLeaveRequests(String token) async {
    await loadLeaveRequests(token, refresh: true);
  }

  Future<void> loadMoreLeaveRequests(String token) async {
    if (!_isLoading && _hasMoreData) {
      await loadLeaveRequests(token);
    }
  }

  void clearData() {
    _leaveRequests.clear();
    _currentPage = 1;
    _hasMoreData = true;
    _isLoading = false;
    _error = null;
    _selectedStatus = null;
    _selectedLeaveType = null;
    _selectedEmployeeId = null;
    _stats = null;
    notifyListeners();
  }
}

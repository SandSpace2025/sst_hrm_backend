import 'package:flutter/material.dart';
import 'package:hrm_app/core/services/api_service.dart';
import 'package:intl/intl.dart';

class Payroll {
  final String? id;
  final double totalPay;
  final double bonus;
  final DateTime payPeriod;
  final Map<String, dynamic>? calculatedFields;
  final Map<String, dynamic>? deductions;
  final Map<String, dynamic>? payslipDetails;

  Payroll({
    this.id,
    required this.totalPay,
    required this.bonus,
    required this.payPeriod,
    this.calculatedFields,
    this.deductions,
    this.payslipDetails,
  });

  factory Payroll.fromJson(Map<String, dynamic> json) {
    return Payroll(
      id: json['_id'],
      totalPay: (json['totalPay'] as num).toDouble(),
      bonus: (json['bonus'] as num).toDouble(),
      payPeriod: DateTime.parse(json['payPeriod']),
      calculatedFields: json['calculatedFields'] != null
          ? Map<String, dynamic>.from(json['calculatedFields'])
          : null,
      deductions: json['deductions'] != null
          ? Map<String, dynamic>.from(json['deductions'])
          : null,
      payslipDetails: json['payslipDetails'] != null
          ? Map<String, dynamic>.from(json['payslipDetails'])
          : null,
    );
  }
}

class PayrollProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Payroll> _payrollHistory = [];
  Payroll? _selectedPayroll;
  DateTime _selectedPayPeriod = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Payroll> get payrollHistory => _payrollHistory;
  Payroll? get selectedPayroll => _selectedPayroll;
  DateTime get selectedPayPeriod => _selectedPayPeriod;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  final TextEditingController totalPayController = TextEditingController();
  final TextEditingController bonusController = TextEditingController();

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  String basicPay = '';
  String hra = '';
  String specialAllowance = '';
  String netSalary = '';

  PayrollProvider() {
    totalPayController.addListener(_updateCalculations);
    bonusController.addListener(_updateCalculations);
  }

  void _updateCalculations() {
    final double totalPayValue =
        double.tryParse(totalPayController.text.replaceAll(',', '')) ?? 0.0;
    final double bonusValue =
        double.tryParse(bonusController.text.replaceAll(',', '')) ?? 0.0;

    final double basicValue = totalPayValue * 0.65;
    final double hraValue = totalPayValue * 0.25;
    final double specialValue = totalPayValue * 0.10;
    final double netValue = totalPayValue + bonusValue;

    basicPay = currencyFormat.format(basicValue);
    hra = currencyFormat.format(hraValue);
    specialAllowance = currencyFormat.format(specialValue);
    netSalary = currencyFormat.format(netValue);

    notifyListeners();
  }

  void _updateControllers() {
    if (_selectedPayroll != null) {
      totalPayController.text = _selectedPayroll!.totalPay.toStringAsFixed(0);
      bonusController.text = _selectedPayroll!.bonus.toStringAsFixed(0);
    } else {
      totalPayController.text = '0';
      bonusController.text = '0';
    }
    _updateCalculations();
  }

  Future<void> fetchPayrollData(String employeeId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getPayrollsForEmployee(employeeId, token);
      _payrollHistory = data.map((item) => Payroll.fromJson(item)).toList();

      if (_payrollHistory.isNotEmpty) {
        setPayPeriod(_payrollHistory.first.payPeriod);
      } else {
        setPayPeriod(DateTime.now());
      }
    } catch (e) {
      _error = 'An error occurred: ${e.toString()}';
      _payrollHistory = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPayPeriod(DateTime period) {
    _selectedPayPeriod = DateTime(period.year, period.month);

    Payroll? foundPayroll;
    for (final p in _payrollHistory) {
      if (p.payPeriod.year == _selectedPayPeriod.year &&
          p.payPeriod.month == _selectedPayPeriod.month) {
        foundPayroll = p;
        break;
      }
    }
    _selectedPayroll = foundPayroll;

    _updateControllers();
    notifyListeners();
  }

  Future<bool> savePayroll(
    String employeeId,
    String token, {
    String? userRole,
    Map<String, dynamic>? calculatedFields,
    Map<String, dynamic>? deductions,
    Map<String, dynamic>? payslipDetails,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    final double totalPayValue =
        double.tryParse(totalPayController.text.replaceAll(',', '').trim()) ??
        0.0;
    final double bonusValue =
        double.tryParse(bonusController.text.replaceAll(',', '').trim()) ?? 0.0;

    final Map<String, dynamic> payload = {
      'totalPay': totalPayValue,
      'bonus': bonusValue,
      if (calculatedFields != null) 'calculatedFields': calculatedFields,
      if (deductions != null) 'deductions': deductions,
      if (payslipDetails != null) 'payslipDetails': payslipDetails,
    };

    try {
      if (_selectedPayroll?.id != null) {
        final updatedData = await _apiService.updatePayroll(
          _selectedPayroll!.id!,
          payload,
          token,
        );
        final updatedPayroll = Payroll.fromJson(updatedData);

        final index = _payrollHistory.indexWhere(
          (p) => p.id == updatedPayroll.id,
        );
        if (index != -1) {
          _payrollHistory[index] = updatedPayroll;
          _selectedPayroll = updatedPayroll;
        }
      } else {
        payload['employeeId'] = employeeId;
        payload['payPeriod'] = _selectedPayPeriod.toIso8601String();
        if (userRole != null) {
          payload['userRole'] = userRole;
        }

        final newData = await _apiService.createPayroll(payload, token);
        final newPayroll = Payroll.fromJson(newData);

        _payrollHistory.add(newPayroll);
        _selectedPayroll = newPayroll;
      }

      _updateControllers();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deletePayroll(String employeeId, String token) async {
    if (_selectedPayroll?.id == null) {
      _error = 'No payroll record selected to delete.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deletePayroll(_selectedPayroll!.id!, token);

      _payrollHistory.removeWhere((p) => p.id == _selectedPayroll!.id);
      setPayPeriod(_selectedPayPeriod);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearData() {
    _payrollHistory = [];
    _selectedPayroll = null;
    _selectedPayPeriod = DateTime.now();
    _isLoading = false;
    _isSaving = false;
    _error = null;
    totalPayController.clear();
    bonusController.clear();
    basicPay = '';
    hra = '';
    specialAllowance = '';
    netSalary = '';
    notifyListeners();
  }

  @override
  void dispose() {
    totalPayController.removeListener(_updateCalculations);
    bonusController.removeListener(_updateCalculations);
    totalPayController.dispose();
    bonusController.dispose();
    super.dispose();
  }
}

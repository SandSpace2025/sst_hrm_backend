import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/services/optimized_api_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hrm_app/presentation/screens/common/pdf_viewer_screen.dart';

import 'package:hrm_app/core/theme/app_colors.dart';

class HRPayrollManagementScreen extends StatefulWidget {
  final Map<String, dynamic> payslipRequest;

  const HRPayrollManagementScreen({super.key, required this.payslipRequest});

  @override
  State<HRPayrollManagementScreen> createState() =>
      _HRPayrollManagementScreenState();
}

class _HRPayrollManagementScreenState extends State<HRPayrollManagementScreen> {
  final TextEditingController _totalPayController = TextEditingController(
    text: '0',
  );

  final TextEditingController _basicPayController = TextEditingController(
    text: '0',
  );
  final TextEditingController _hraController = TextEditingController(text: '0');
  final TextEditingController _specialAllowanceController =
      TextEditingController(text: '0');
  final TextEditingController _bonusController = TextEditingController(
    text: '0',
  );

  final TextEditingController _pfController = TextEditingController(text: '0');
  final TextEditingController _esiController = TextEditingController(text: '0');
  final TextEditingController _ptController = TextEditingController(text: '0');
  final TextEditingController _lopController = TextEditingController(text: '0');
  final TextEditingController _penaltyController = TextEditingController(
    text: '0',
  );

  final TextEditingController _panController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _pfNumberController = TextEditingController();
  final TextEditingController _uanController = TextEditingController();
  final TextEditingController _paidDaysController = TextEditingController();
  final TextEditingController _lopDaysController = TextEditingController();

  bool _isProcessing = false;

  bool _isReadOnly = true;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  double _grossEarnings = 0.0;
  double _totalDeductions = 0.0;
  double _netSalary = 0.0;

  @override
  void initState() {
    super.initState();

    final status = widget.payslipRequest['status'];
    if (status == 'pending' ||
        status == 'processing' ||
        status == 'hold' ||
        status == 'on-hold') {
      _isReadOnly = false;
    }

    _totalPayController.addListener(_autoCalculateFromTotalPay);

    _basicPayController.addListener(_calculateFields);
    _hraController.addListener(_calculateFields);
    _specialAllowanceController.addListener(_calculateFields);
    _bonusController.addListener(_calculateFields);
    _pfController.addListener(_calculateFields);
    _esiController.addListener(_calculateFields);
    _ptController.addListener(_calculateFields);
    _lopController.addListener(_calculateFields);
    _penaltyController.addListener(_calculateFields);

    if (widget.payslipRequest['basePay'] != null) {
      final basePay = widget.payslipRequest['basePay'];

      _totalPayController.text = basePay.toStringAsFixed(0);
    } else if (widget.payslipRequest['calculatedFields'] != null) {
      final calcFields = widget.payslipRequest['calculatedFields'];

      if (calcFields['basicPay'] != null) {
        final basicPay = calcFields['basicPay'] as num;

        final totalPay = basicPay / 0.65;
        _totalPayController.text = totalPay.toStringAsFixed(0);
      }
      if (calcFields['hra'] != null) {
        _hraController.text = calcFields['hra'].toStringAsFixed(0);
      }
      if (calcFields['specialAllowance'] != null) {
        _specialAllowanceController.text = calcFields['specialAllowance']
            .toStringAsFixed(0);
      }
      if (calcFields['bonus'] != null) {
        _bonusController.text = calcFields['bonus'].toStringAsFixed(0);
      }
    }
    if (widget.payslipRequest['deductions'] != null) {
      final deductions = widget.payslipRequest['deductions'];
      if (deductions['pf'] != null) {
        _pfController.text = deductions['pf'].toStringAsFixed(0);
      }
      if (deductions['esi'] != null) {
        _esiController.text = deductions['esi'].toStringAsFixed(0);
      }
      if (deductions['pt'] != null) {
        _ptController.text = deductions['pt'].toStringAsFixed(0);
      }
      if (deductions['lop'] != null) {
        _lopController.text = deductions['lop'].toStringAsFixed(0);
      }
      if (deductions['penalty'] != null) {
        _penaltyController.text = deductions['penalty'].toStringAsFixed(0);
      }
    }
    if (widget.payslipRequest['payslipDetails'] != null) {
      final details = widget.payslipRequest['payslipDetails'];
      if (details['pan'] != null) _panController.text = details['pan'];
      if (details['bankName'] != null) {
        _bankNameController.text = details['bankName'];
      }
      if (details['accountNumber'] != null) {
        _accountNumberController.text = details['accountNumber'];
      }
      if (details['pfNumber'] != null) {
        _pfNumberController.text = details['pfNumber'];
      }
      if (details['uan'] != null) _uanController.text = details['uan'];
      if (details['paidDays'] != null) {
        _paidDaysController.text = details['paidDays'].toString();
      }
      if (details['lopDays'] != null) {
        _lopDaysController.text = details['lopDays'].toString();
      }
    }

    _calculateFields();
  }

  Future<void> _updateRequestStatus(
    String status, {
    String? rejectionReason,
    String? payslipUrl,
    Map<String, dynamic>? payrollData,
  }) async {
    final requestId = widget.payslipRequest['_id']?.toString();
    if (requestId == null || requestId.isEmpty) {
      _showErrorSnackBar('Invalid payslip request.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      if (authProvider.token == null || authProvider.token!.isEmpty) {
        _showErrorSnackBar(
          'Authentication token is missing. Please login again.',
        );
        setState(() => _isProcessing = false);
        return;
      }

      final payload = <String, dynamic>{'status': status};
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        payload['rejectionReason'] = rejectionReason;
      }
      if (payslipUrl != null && payslipUrl.isNotEmpty) {
        payload['payslipUrl'] = payslipUrl;
      }
      if (payrollData != null) payload.addAll(payrollData);

      await OptimizedApiService.updatePayslipRequestStatus(
        authProvider.token!,
        requestId,
        payload,
      );

      await hrProvider.loadPayslipRequests(
        authProvider.token!,
        forceRefresh: true,
      );

      if (mounted) {
        _showSuccessSnackBar('Request updated successfully.');

        if (status == 'on-hold') {
          setState(() {
            _isReadOnly = false;

            widget.payslipRequest['status'] = 'hold';
          });
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _extractErrorMessage(e);
        _showErrorSnackBar('Failed to update request: $errorMessage');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPayslip() async {
    final TextEditingController reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Payslip Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason here...',
                  filled: true,
                  fillColor: AppColors.edgeBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.edgeDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.edgeDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.edgePrimary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateRequestStatus(
        'rejected',
        rejectionReason: reasonController.text.trim(),
      );
    }
  }

  Future<void> _previewPayslip() async {
    final payrollData = _collectPayrollData();
    if (payrollData == null) return;

    setState(() => _isProcessing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final requestId = widget.payslipRequest['_id']?.toString();

      if (requestId == null) {
        _showErrorSnackBar('Invalid request ID');
        return;
      }

      final pdfBytes = await OptimizedApiService.previewPayslip(
        authProvider.token!,
        requestId,
        payrollData,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/payslip_preview.pdf');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              filePath: file.path,
              title: 'Payslip Preview',
              onApprove: () {
                Navigator.pop(context);
                _processPayslip();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _extractErrorMessage(e);
        _showErrorSnackBar('Failed to preview payslip: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _holdPayslip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hold Payslip Request'),
          content: const Text(
            'Are you sure you want to put this request on hold? Current data will be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hold'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final payrollData = _collectPayrollData();

      await _updateRequestStatus('on-hold', payrollData: payrollData);
    }
  }

  Map<String, dynamic>? _collectPayrollData() {
    final totalPayValue =
        double.tryParse(_totalPayController.text.replaceAll(',', '')) ?? 0.0;
    final basicPayValue =
        double.tryParse(_basicPayController.text.replaceAll(',', '')) ?? 0.0;
    final hraValue =
        double.tryParse(_hraController.text.replaceAll(',', '')) ?? 0.0;
    final specialAllowance =
        double.tryParse(_specialAllowanceController.text.replaceAll(',', '')) ??
        0.0;
    final bonus =
        double.tryParse(_bonusController.text.replaceAll(',', '')) ?? 0.0;

    final basePay = totalPayValue > 0
        ? totalPayValue
        : (basicPayValue + hraValue + specialAllowance);

    if (basePay <= 0) {
      _showErrorSnackBar('Please enter Total Pay or Basic Pay/HRA amounts');
      return null;
    }

    return {
      'basePay': basePay,
      'bonus': bonus,
      'calculatedFields': {
        'basicPay': basicPayValue,
        'hra': hraValue,
        'specialAllowance': specialAllowance,
        'netSalary': _netSalary,
        'bonus': bonus,
      },
      'deductions': {
        'pf': double.tryParse(_pfController.text.replaceAll(',', '')) ?? 0.0,
        'esi': double.tryParse(_esiController.text.replaceAll(',', '')) ?? 0.0,
        'pt': double.tryParse(_ptController.text.replaceAll(',', '')) ?? 0.0,
        'lop': double.tryParse(_lopController.text.replaceAll(',', '')) ?? 0.0,
        'penalty':
            double.tryParse(_penaltyController.text.replaceAll(',', '')) ?? 0.0,
      },
      'payslipDetails': {
        'pan': _panController.text.trim().isEmpty
            ? null
            : _panController.text.trim(),
        'bankName': _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        'pfNumber': _pfNumberController.text.trim().isEmpty
            ? null
            : _pfNumberController.text.trim(),
        'uan': _uanController.text.trim().isEmpty
            ? null
            : _uanController.text.trim(),
        'paidDays': _paidDaysController.text.trim().isEmpty
            ? null
            : int.tryParse(_paidDaysController.text.trim()),
        'lopDays':
            int.tryParse(_lopDaysController.text.replaceAll(',', '')) ?? 0,
      },
    };
  }

  @override
  void dispose() {
    _totalPayController.dispose();
    _basicPayController.dispose();
    _hraController.dispose();
    _specialAllowanceController.dispose();
    _bonusController.dispose();
    _pfController.dispose();
    _esiController.dispose();
    _ptController.dispose();
    _lopController.dispose();
    _penaltyController.dispose();
    _panController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _pfNumberController.dispose();
    _uanController.dispose();
    _paidDaysController.dispose();
    _lopDaysController.dispose();
    super.dispose();
  }

  void _autoCalculateFromTotalPay() {
    if (!mounted) return;

    final totalPayValue =
        double.tryParse(_totalPayController.text.replaceAll(',', '').trim()) ??
        0.0;

    if (totalPayValue > 0) {
      final basicPay = totalPayValue * 0.65;
      final hra = totalPayValue * 0.25;
      final specialAllowance = totalPayValue * 0.10;

      _basicPayController.removeListener(_calculateFields);
      _hraController.removeListener(_calculateFields);
      _specialAllowanceController.removeListener(_calculateFields);

      _basicPayController.text = basicPay.toStringAsFixed(0);
      _hraController.text = hra.toStringAsFixed(0);
      _specialAllowanceController.text = specialAllowance.toStringAsFixed(0);

      _basicPayController.addListener(_calculateFields);
      _hraController.addListener(_calculateFields);
      _specialAllowanceController.addListener(_calculateFields);

      _calculateFields();
    }
  }

  void _calculateFields() {
    if (!mounted) return;

    final basicPayValue =
        double.tryParse(_basicPayController.text.replaceAll(',', '').trim()) ??
        0.0;
    final hraValue =
        double.tryParse(_hraController.text.replaceAll(',', '').trim()) ?? 0.0;
    final specialAllowanceValue =
        double.tryParse(
          _specialAllowanceController.text.replaceAll(',', '').trim(),
        ) ??
        0.0;
    final pfValue =
        double.tryParse(_pfController.text.replaceAll(',', '').trim()) ?? 0.0;
    final esiValue =
        double.tryParse(_esiController.text.replaceAll(',', '').trim()) ?? 0.0;
    final ptValue =
        double.tryParse(_ptController.text.replaceAll(',', '').trim()) ?? 0.0;
    final lopValue =
        double.tryParse(_lopController.text.replaceAll(',', '').trim()) ?? 0.0;
    final penaltyValue =
        double.tryParse(_penaltyController.text.replaceAll(',', '').trim()) ??
        0.0;

    final grossEarnings = basicPayValue + hraValue + specialAllowanceValue;
    final totalDeductions =
        pfValue + esiValue + ptValue + lopValue + penaltyValue;
    final bonusValue =
        double.tryParse(_bonusController.text.replaceAll(',', '').trim()) ??
        0.0;

    final netSalary = grossEarnings + bonusValue - totalDeductions;

    if (mounted) {
      setState(() {
        _grossEarnings = grossEarnings;
        _totalDeductions = totalDeductions;
        _netSalary = netSalary;
      });
    }
  }

  Future<void> _processPayslip() async {
    final totalPay =
        double.tryParse(_totalPayController.text.replaceAll(',', '')) ?? 0.0;
    final basicPay =
        double.tryParse(_basicPayController.text.replaceAll(',', '')) ?? 0.0;
    final hra = double.tryParse(_hraController.text.replaceAll(',', '')) ?? 0.0;

    if (totalPay <= 0 && (basicPay <= 0 && hra <= 0)) {
      _showErrorSnackBar('Please enter Total Pay or Basic Pay/HRA amounts');
      return;
    }

    final requestId = widget.payslipRequest['_id']?.toString();
    if (requestId == null || requestId.isEmpty) {
      _showErrorSnackBar('Invalid payslip request. Please try again.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      if (authProvider.token == null || authProvider.token!.isEmpty) {
        _showErrorSnackBar(
          'Authentication token is missing. Please login again.',
        );
        setState(() => _isProcessing = false);
        return;
      }

      final payrollData = _collectPayrollData();
      if (payrollData == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await OptimizedApiService.processPayslipWithBasePay(
        authProvider.token!,
        requestId,
        payrollData,
      );

      await hrProvider.loadPayslipRequests(
        authProvider.token!,
        forceRefresh: true,
      );

      if (mounted) {
        _showSuccessSnackBar('Payslip processed and approved successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _extractErrorMessage(e);
        _showErrorSnackBar('Failed to process payslip: $errorMessage');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _extractErrorMessage(dynamic error) {
    String errorStr = error.toString();

    if (error is HttpException) {
      errorStr = error.message;
    }

    errorStr = errorStr.replaceAll(RegExp(r'<[^>]*>'), '');

    errorStr = errorStr
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    errorStr = errorStr.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (errorStr.length > 200 ||
        errorStr.contains('<!DOCTYPE') ||
        errorStr.contains('<html')) {
      return 'An error occurred while processing the payslip. Please try again.';
    }

    if (errorStr.isEmpty || errorStr.trim().isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }

    return errorStr;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.edgeAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.payslipRequest['employee'] ?? {};
    final employeeName = employee['name'] ?? 'Unknown Employee';
    final employeeId = employee['employeeId'] ?? 'N/A';
    final startMonth = widget.payslipRequest['startMonth'] ?? '';
    final startYear = widget.payslipRequest['startYear'] ?? '';
    final endMonth = widget.payslipRequest['endMonth'] ?? '';
    final endYear = widget.payslipRequest['endYear'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      appBar: AppBar(
        backgroundColor: AppColors.edgeSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.edgeText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payroll Management',
          style: TextStyle(
            color: AppColors.edgeText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.edgePrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.edgePrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.edgeText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Employee ID: $employeeId',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.edgeTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildInfoItem('Designation', employee['jobTitle'] ?? 'N/A'),
                  _buildInfoItem(
                    'Date of Joining',
                    employee['joinDate'] != null
                        ? DateFormat(
                            'dd/MM/yyyy',
                          ).format(DateTime.parse(employee['joinDate']))
                        : 'N/A',
                  ),
                  _buildInfoItem(
                    'Period',
                    '$startMonth $startYear - $endMonth $endYear',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppColors.edgeAccent,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'EARNINGS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildMoneyField(
                    'Total Pay',
                    _totalPayController,
                    isEditable: true,
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppColors.edgeDivider),
                  const SizedBox(height: 12),

                  _buildMoneyField(
                    'Basic Salary (65%)',
                    _basicPayController,
                    isEditable: false,
                  ),
                  _buildMoneyField(
                    'House Rent Allowance (25%)',
                    _hraController,
                    isEditable: false,
                  ),
                  _buildMoneyField(
                    'Special Allowance (10%)',
                    _specialAllowanceController,
                    isEditable: false,
                  ),
                  _buildMoneyField(
                    'Bonus',
                    _bonusController,
                    isEditable: false,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gross Earnings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                      Text(
                        currencyFormat.format(_grossEarnings),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.edgeError,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'DEDUCTIONS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMoneyField('PF', _pfController, isEditable: false),
                  _buildMoneyField('ESI', _esiController, isEditable: false),
                  _buildMoneyField(
                    'Professional Tax',
                    _ptController,
                    isEditable: false,
                  ),
                  _buildMoneyField('LOP', _lopController, isEditable: false),
                  _buildMoneyField(
                    'Penalties',
                    _penaltyController,
                    isEditable: false,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Deductions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                      Text(
                        currencyFormat.format(_totalDeductions),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeError,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.edgePrimary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Payslip Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSmallInputField(
                    'PAN',
                    _panController,
                    'PAN Number',
                    isEditable: false,
                  ),
                  const SizedBox(height: 12),
                  _buildSmallInputField(
                    'Bank Name',
                    _bankNameController,
                    'Bank Name',
                    isEditable: false,
                  ),
                  const SizedBox(height: 12),
                  _buildSmallInputField(
                    'Account Number',
                    _accountNumberController,
                    'Account Number',
                    isEditable: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmallInputField(
                          'PF Number',
                          _pfNumberController,
                          'PF Number',
                          isEditable: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSmallInputField(
                          'UAN',
                          _uanController,
                          'UAN',
                          isEditable: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmallInputField(
                          'Paid Days',
                          _paidDaysController,
                          'Paid Days',
                          isEditable: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSmallInputField(
                          'LOP Days',
                          _lopDaysController,
                          'LOP Days',
                          isEditable: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.edgePrimary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'NET PAY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCalculatedField('Gross Earnings', _grossEarnings),
                  const SizedBox(height: 12),
                  _buildCalculatedField('Total Deductions', _totalDeductions),
                  const Divider(height: 24),
                  _buildCalculatedField(
                    'Net Salary',
                    _netSalary,
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _previewPayslip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.edgeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Preview Payslip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _rejectPayslip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.edgeError,
                      side: const BorderSide(color: AppColors.edgeError),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _holdPayslip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.edgeWarning,
                      side: BorderSide(
                        color: AppColors.edgeWarning.withOpacity(0.9),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Hold'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMoneyField(
    String label,
    TextEditingController controller, {
    bool isEditable = true,
  }) {
    final bool isFieldReadOnly = _isReadOnly || !isEditable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.edgeTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            height: 40,
            child: TextFormField(
              controller: controller,
              readOnly: isFieldReadOnly,
              textAlign: TextAlign.right,
              keyboardType: isFieldReadOnly
                  ? TextInputType.none
                  : const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                if (isFieldReadOnly) return;

                if (controller == _totalPayController) {
                  _autoCalculateFromTotalPay();
                } else {
                  _calculateFields();
                }
              },
              decoration: InputDecoration(
                prefixText: '₹',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: AppColors.edgeDivider,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: AppColors.edgeDivider,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: AppColors.edgePrimary,
                    width: 1.5,
                  ),
                ),
                fillColor: isFieldReadOnly ? Colors.grey.shade100 : null,
                filled: isFieldReadOnly,
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isFieldReadOnly
                    ? AppColors.edgeTextSecondary
                    : AppColors.edgeText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInputField(
    String label,
    TextEditingController controller,
    String hintText, {
    bool isEditable = true,
  }) {
    final bool isFieldReadOnly = _isReadOnly || !isEditable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isFieldReadOnly,
          keyboardType: isFieldReadOnly
              ? TextInputType.none
              : (label.contains('Days') || label.contains('Number')
                    ? TextInputType.number
                    : TextInputType.text),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isFieldReadOnly
                ? Colors.grey.shade100
                : AppColors.edgeBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.edgePrimary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          style: TextStyle(
            color: isFieldReadOnly
                ? AppColors.edgeTextSecondary
                : AppColors.edgeText,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.edgeTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.edgeText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatedField(
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            color: AppColors.edgeText,
          ),
        ),
        Text(
          currencyFormat.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            color: isTotal ? AppColors.edgeAccent : AppColors.edgePrimary,
          ),
        ),
      ],
    );
  }
}

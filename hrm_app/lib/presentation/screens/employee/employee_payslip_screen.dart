import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/presentation/widgets/payslip/current_salary_card.dart';
import 'package:hrm_app/presentation/widgets/payslip/payslip_request_card.dart';
import 'package:hrm_app/presentation/widgets/common/notification_icon_button.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class EmployeePayslipScreen extends StatefulWidget {
  final int? initialTabIndex;

  const EmployeePayslipScreen({super.key, this.initialTabIndex});

  @override
  State<EmployeePayslipScreen> createState() => _EmployeePayslipScreenState();
}

class _EmployeePayslipScreenState extends State<EmployeePayslipScreen> {
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      try {
        await Future.wait([
          employeeProvider.loadEmployeeProfile(
            authProvider.token!,
            forceRefresh: true,
          ),
          employeeProvider.loadPayslips(
            authProvider.token!,
            forceRefresh: true,
          ),
          employeeProvider.loadCurrentSalary(
            authProvider.token!,
            forceRefresh: true,
          ),
          employeeProvider.loadPayslipRequests(
            authProvider.token!,
            forceRefresh: true,
          ),
          employeeProvider.loadSalaryBreakdown(
            authProvider.token!,
            _getMonthName(DateTime.now().month),
            DateTime.now().year,
          ),
        ]);
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (!errorMsg.contains('socketexception') &&
            !errorMsg.contains('no internet connection') &&
            !errorMsg.contains('network')) {
          if (mounted) {
            _showErrorSnackBar('Failed to load payslip data: ${e.toString()}');
          }
        }
      }
    }

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, child) {
        return const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payslip',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your earnings! Your freedom!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            NotificationIconButton(),
          ],
        );
      },
    );
  }

  DateTime _selectedDate = DateTime.now();
  DateTime _breakdownDate = DateTime.now();

  Future<void> _requestPayslip() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        final currentMonth = _getMonthName(_selectedDate.month);
        final currentYear = _selectedDate.year.toString();

        await employeeProvider.submitPayslipRequest(
          authProvider.token!,
          currentMonth,
          currentYear,
          currentMonth,
          currentYear,
          'Payslip request for $currentMonth $currentYear',
        );

        await employeeProvider.refreshPayslipRequests(authProvider.token!);

        if (mounted) {
          Navigator.pop(context); // Close the dialog
          _showSuccessSnackBar(
            'Payslip request submitted successfully! HR will be notified.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to submit payslip request: ${e.toString()}');
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: AppColors.edgeBackground,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Shimmer
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading.rectangular(width: 120, height: 32),
                      SizedBox(height: 8),
                      ShimmerLoading.rectangular(width: 200, height: 16),
                    ],
                  ),
                  ShimmerLoading.circular(width: 40),
                ],
              ),
              const SizedBox(height: 24),

              // Salary Card Shimmer
              ShimmerLoading.card(height: 220, margin: EdgeInsets.zero),
              const SizedBox(height: 24),

              // Note Card Shimmer
              ShimmerLoading.rectangular(width: double.infinity, height: 60),
              const SizedBox(height: 32),

              // Breakdown Section Shimmer
              const ShimmerLoading.rectangular(width: 150, height: 24),
              const SizedBox(height: 16),
              ShimmerLoading.card(height: 280, margin: EdgeInsets.zero),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            if (authProvider.token != null) {
              await _loadInitialData();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 32),

                // Current Salary Section
                const CurrentSalaryCard(),
                const SizedBox(height: 16),

                // Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF616161),
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Note: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(
                          text:
                              'Salary will be credited between 10th-15th of the following month!',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Salary Breakdown Section
                _buildSalaryBreakdownSection(),
                const SizedBox(height: 32),

                // Recent Payslips Section
                _buildRecentPayslipsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryBreakdownSection() {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final salaryBreakdown = employeeProvider.salaryBreakdown;
        final hasData =
            salaryBreakdown != null && salaryBreakdown['hasData'] == true;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Salary breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  // Month/Year Selector
                  Row(
                    children: [
                      _buildCompactDropdown(
                        value: _breakdownDate.month,
                        items: List.generate(12, (index) => index + 1),
                        labelBuilder: (idx) =>
                            _getMonthName(idx).substring(0, 3),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _breakdownDate = DateTime(
                                _breakdownDate.year,
                                val,
                              );
                            });
                            _loadBreakdownData(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildCompactDropdown(
                        value: _breakdownDate.year,
                        items: List.generate(
                          5,
                          (index) => DateTime.now().year - index,
                        ),
                        labelBuilder: (val) => val.toString(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _breakdownDate = DateTime(
                                val,
                                _breakdownDate.month,
                              );
                            });
                            _loadBreakdownData(context);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!hasData)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.lock_clock,
                        size: 48,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Breakdown unavailable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        salaryBreakdown?['message'] ??
                            'No data for selected period',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _buildBreakdownRow(
                  'Basic Monthly Salary',
                  '₹${_formatCurrency(salaryBreakdown['basicPay'])}',
                ),
                const SizedBox(height: 16),
                _buildBreakdownRow(
                  'Professional Tax',
                  '₹${_formatCurrency(salaryBreakdown['pt'] ?? 0)}',
                ),
                const SizedBox(height: 16),
                _buildBreakdownRow(
                  'PF',
                  '₹${_formatCurrency(salaryBreakdown['pf'] ?? 0)}',
                ),
                const SizedBox(height: 16),
                _buildBreakdownRow(
                  'ESI',
                  '₹${_formatCurrency(salaryBreakdown['esi'] ?? 0)}',
                ),
                const SizedBox(height: 16),
                _buildBreakdownRow(
                  'Lop days',
                  '${salaryBreakdown['lopDays']} Days',
                ),
                const SizedBox(height: 16),
                _buildBreakdownRow(
                  'Penalties',
                  '₹${_formatCurrency(salaryBreakdown['penalty'])}',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Salary',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF616161),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${_formatCurrency(salaryBreakdown['netSalary'])}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _loadBreakdownData(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );
    if (authProvider.token != null) {
      employeeProvider.loadSalaryBreakdown(
        authProvider.token!,
        _getMonthName(_breakdownDate.month),
        _breakdownDate.year,
      );
    }
  }

  Widget _buildCompactDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelBuilder(item),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF424242),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPayslipsSection() {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final payslips = employeeProvider.payslipRequests;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Payslips',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF616161),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showPayslipRequestDialog();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Payslip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (payslips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 48,
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No payslip requests found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Request a new payslip to see it here',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ...payslips.take(3).map((payslip) => _buildPayslipItem(payslip)),
          ],
        );
      },
    );
  }

  Widget _buildPayslipItem(Map<String, dynamic> payslip) {
    // Check if it's a request object (has startMonth) or legacy payslip object
    // Key mapping
    final monthData = payslip['startMonth'] ?? payslip['month'];
    final yearData = payslip['startYear'] ?? payslip['year'];

    // Robust month handling
    String monthName = '';
    if (monthData is int) {
      monthName = _getMonthName(monthData);
    } else if (monthData is String) {
      monthName = monthData;
    } else {
      monthName = _getMonthName(1);
    }

    final monthYear = '$monthName ${yearData ?? ''}';
    final status = payslip['status'] ?? 'Approved';

    // Amount handling - Request object might nested amount in calculatedFields
    dynamic amount = 0;
    if (payslip['calculatedFields'] != null &&
        payslip['calculatedFields'] is Map) {
      amount = payslip['calculatedFields']['netSalary'] ?? 0;
    } else {
      amount =
          payslip['netSalary'] ?? payslip['totalPay'] ?? payslip['amount'] ?? 0;
    }

    // Formatting status for display
    Color statusColor = AppColors.primary;
    String statusText = 'Approved';
    if (status == 'pending') {
      statusColor = AppColors.warning;
      statusText = 'Waitlisted';
    } else if (status == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'Rejected';
    } else if (status == 'processing') {
      statusColor = Colors.blue;
      statusText = 'Processing';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthYear,
                style: const TextStyle(
                  fontSize: 16, // Increased size
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242), // Darker for visibility
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Transaction ID',
            payslip['transactionId'] ?? '021221293232',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Bank destination',
            payslip['bankAccount'] ?? '294214214212',
          ), // Mock if missing
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salary amount',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${_formatCurrency(amount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600, // SemiBold
                  color: Color(0xFF424242),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: () {
                // Open details
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('View details', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF424242),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF424242)),
        ),
      ],
    );
  }

  void _showPayslipRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: PayslipRequestCard(
                onRequestTap: _requestPayslip,
                selectedDate: _selectedDate,
                onDateSelect: () => _selectMonthYear(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonthYear(BuildContext context) async {
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Month & Year'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedYear,
                          isExpanded: true,
                          items: List.generate(5, (index) {
                            int year = DateTime.now().year - index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (val) {
                            setState(() {
                              selectedYear = val!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          isExpanded: true,
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(
                              value: index + 1,
                              child: Text(_getMonthName(index + 1)),
                            );
                          }),
                          onChanged: (val) {
                            setState(() {
                              selectedMonth = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _selectedDate = DateTime(selectedYear, selectedMonth);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final numAmount = amount is num
        ? amount
        : double.tryParse(amount.toString()) ?? 0;
    return numAmount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

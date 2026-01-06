import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayslipApprovalHistoryList extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final bool isLoading;
  final Function(String? startDate, String? endDate, String? employeeId)?
  onFilter;

  const PayslipApprovalHistoryList({
    super.key,
    required this.history,
    required this.isLoading,
    this.onFilter,
  });

  @override
  State<PayslipApprovalHistoryList> createState() =>
      _PayslipApprovalHistoryListState();
}

class _PayslipApprovalHistoryListState extends State<PayslipApprovalHistoryList>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  String? _selectedEmployeeName;
  final TextEditingController _employeeSearchController =
      TextEditingController();

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _animDuration,
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  Widget _animatedWidget({required Widget child, required double interval}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(interval, 1.0, curve: _animCurve),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(interval, 1.0, curve: _animCurve),
              ),
            ),
        child: child,
      ),
    );
  }

  void _applyFilters() {
    widget.onFilter?.call(null, null, _selectedEmployeeName);
  }

  void _clearFilters() {
    setState(() {
      _selectedEmployeeName = null;
      _employeeSearchController.clear();
    });
    _applyFilters();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.edgeAccent;
      case 'rejected':
        return AppColors.edgeError;
      case 'on-hold':
      case 'on_hold':
        return AppColors.edgeWarning;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'on-hold':
      case 'on_hold':
        return Icons.pause_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _animatedWidget(
        interval: 0.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _animatedWidget(
              interval: 0.1,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_list,
                          color: AppColors.edgePrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.edgeText,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: AppColors.edgePrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _employeeSearchController,
                      decoration: InputDecoration(
                        labelText: 'Search by Employee Name',
                        hintText: 'Enter employee name...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.edgePrimary,
                        ),
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
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedEmployeeName = value.isEmpty ? null : value;
                        });
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (widget.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (widget.history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.edgeTextSecondary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No approval history found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Approved and rejected payslips will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...widget.history.asMap().entries.map((entry) {
                final index = entry.key;
                final record = entry.value;
                final employee = record['employee'] as Map<String, dynamic>?;
                final processedBy =
                    record['processedBy'] as Map<String, dynamic>?;
                final status = record['status'] as String? ?? 'unknown';
                final processedAt = record['processedAt'] as String?;
                final processedDate = record['processedDate'] as String?;
                final processedTime = record['processedTime'] as String?;

                return _animatedWidget(
                  interval: 0.3 + (index * 0.05),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.edgeSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.edgeDivider,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusColor(status),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      employee?['name'] ?? 'Unknown Employee',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.edgeText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Employee ID: ${employee?['employeeId'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.edgeTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusLabel(status).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getStatusColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.edgePrimary.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.edgePrimary.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 16,
                                  color: AppColors.edgePrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Payslip For: ${record['startMonth'] ?? 'N/A'} ${record['startYear'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.edgePrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (processedBy != null ||
                              processedDate != null ||
                              processedAt != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.edgeBackground.withValues(
                                  alpha: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.edgeTextSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (processedBy != null)
                                          Text(
                                            'Processed by: ${processedBy['name'] ?? 'Unknown'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.edgeTextSecondary,
                                            ),
                                          ),
                                        if (processedDate != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Date: $processedDate${processedTime != null ? ' at $processedTime' : ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.edgeTextSecondary,
                                            ),
                                          ),
                                        ] else if (processedAt != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Date: ${processedAt.split('T')[0]} at ${processedAt.split('T')[1].split('.')[0]}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.edgeTextSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'on-hold':
      case 'on_hold':
        return 'Hold';
      default:
        return status;
    }
  }
}

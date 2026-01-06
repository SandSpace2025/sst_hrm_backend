import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/hr_payroll/payslip_requests_list.dart';
import 'package:hrm_app/presentation/widgets/hr_payroll/payslip_request_stats_card.dart';
import 'package:hrm_app/presentation/widgets/hr_payroll/payslip_approval_history_list.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AdminPayrollScreen extends StatefulWidget {
  const AdminPayrollScreen({super.key});

  @override
  State<AdminPayrollScreen> createState() => _AdminPayrollScreenState();
}

class _AdminPayrollScreenState extends State<AdminPayrollScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    if (authProvider.token != null) {
      try {
        await Future.wait([
          hrProvider.loadPayslipRequests(authProvider.token!),
          hrProvider.loadPayslipRequestStats(authProvider.token!),
          hrProvider.loadPayslipApprovalHistory(authProvider.token!),
        ]);
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Failed to load payroll data: ${e.toString()}');
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: _isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.edgePrimary,
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: AppColors.edgeSurface,
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.edgeDivider,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.edgePrimary.withValues(alpha: 26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.payment,
                          color: AppColors.edgePrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payroll Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.edgeText,
                              ),
                            ),
                            Text(
                              'Manage payslip requests and payroll operations',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.edgeTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadInitialData,
                        icon: const Icon(
                          Icons.refresh,
                          color: AppColors.edgePrimary,
                        ),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),

                Container(
                  color: AppColors.edgeSurface,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.edgePrimary,
                    labelColor: AppColors.edgePrimary,
                    unselectedLabelColor: AppColors.edgeTextSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.request_page, size: 20),
                        text: 'Payslip Requests',
                      ),
                      Tab(
                        icon: Icon(Icons.analytics, size: 20),
                        text: 'Statistics',
                      ),
                      Tab(
                        icon: Icon(Icons.history, size: 20),
                        text: 'Approval History',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      Consumer<HRProvider>(
                        builder: (context, hrProvider, child) {
                          return PayslipRequestsList(
                            requests: hrProvider.payslipRequests,
                            isLoading: hrProvider.isLoading,
                            onStatusUpdate:
                                (
                                  requestId,
                                  status,
                                  payslipUrl,
                                  rejectionReason,
                                ) async {
                                  try {
                                    final authProvider =
                                        Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                    await hrProvider.updatePayslipRequestStatus(
                                      authProvider.token!,
                                      requestId,
                                      status,
                                      payslipUrl: payslipUrl,
                                      rejectionReason: rejectionReason,
                                    );
                                    _showSuccessSnackBar(
                                      'Request status updated successfully',
                                    );
                                    await _loadInitialData();
                                  } catch (e) {
                                    _showErrorSnackBar(
                                      'Failed to update request: ${e.toString()}',
                                    );
                                  }
                                },
                          );
                        },
                      ),

                      Consumer<HRProvider>(
                        builder: (context, hrProvider, child) {
                          return PayslipRequestStatsCard(
                            stats: hrProvider.payslipRequestStats,
                            isLoading: hrProvider.isLoading,
                          );
                        },
                      ),

                      Consumer<HRProvider>(
                        builder: (context, hrProvider, child) {
                          return PayslipApprovalHistoryList(
                            history: hrProvider.payslipApprovalHistory,
                            isLoading: hrProvider.isLoading,
                            onFilter: (startDate, endDate, employeeName) async {
                              try {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                await hrProvider.loadPayslipApprovalHistory(
                                  authProvider.token!,
                                  employeeName: employeeName,
                                );
                              } catch (e) {
                                _showErrorSnackBar(
                                  'Failed to filter history: ${e.toString()}',
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/widgets/employee_leave/leave_balance_circles.dart';
import 'package:hrm_app/presentation/widgets/employee_leave/leave_request_card.dart';
import 'package:hrm_app/presentation/screens/employee/create_leave_request_screen.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  final int
  initialTabIndex; // Kept for interface compatibility, though unused now
  const EmployeeLeaveScreen({super.key, this.initialTabIndex = 0});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  bool _isInitialLoading = true;
  String _filterStatus = 'all'; // Kept for future filtering if needed
  String _filterLeaveType = 'all'; // Kept for future filtering if needed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
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
          employeeProvider.loadLeaveRequests(authProvider.token!),
          employeeProvider.loadLeaveBalance(authProvider.token!),
          employeeProvider.loadLeaveStatistics(authProvider.token!),
          // employeeProvider.loadBlackoutDates(authProvider.token!),
        ]);
      } catch (e) {
        if (mounted) {
          // _showErrorSnackBar('Failed to load data: ${e.toString()}');
        }
      }
    }

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isInitialLoading
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  ShimmerLoading.card(
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  ShimmerLoading.card(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                  ShimmerLoading.card(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                physics:
                    const AlwaysScrollableScrollPhysics(), // Ensure refresh works even if content is short
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LeaveBalanceCircles(),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My leave Requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Edit, and Manage leaves',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateLeaveRequestScreen(),
                              ),
                            ).then((_) => _loadInitialData());
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLeaveRequestsList(),
                    const SizedBox(height: 80), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLeaveRequestsList() {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        if (employeeProvider.leaveRequests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text("No leave requests found")),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: employeeProvider.leaveRequests.length,
          itemBuilder: (context, index) {
            final rawRequest = employeeProvider.leaveRequests[index];
            if (rawRequest == null || rawRequest is! Map) {
              return const SizedBox.shrink();
            }
            final request = Map<String, dynamic>.from(rawRequest);
            return LeaveRequestCard(
              request: request,
              onActionTap: () => _handleCancel(request, employeeProvider),
            );
          },
        );
      },
    );
  }

  void _handleCancel(Map<String, dynamic> request, EmployeeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Leave?'),
        content: const Text('Are you sure you want to withdraw this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              if (authProvider.token != null) {
                try {
                  await provider.cancelLeaveRequest(
                    authProvider.token!,
                    request['_id'] ?? request['id'],
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Leave request withdrawn'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                  _loadInitialData(); // Refresh data
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}

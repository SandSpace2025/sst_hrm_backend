import 'package:flutter/material.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/hr_create_new_employee.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/hr_employee_list_card.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/hr_employee_search_field.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/hr_read_update_delete_employee_widget.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/sub_pages/hr_payroll_viewer_page.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/sub_pages/hr_eod_viewer_page.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/manage_employees/sub_pages/hr_leave_management_page.dart';
import 'package:hrm_app/presentation/widgets/hr_payroll/payslip_requests_list.dart';
import 'package:hrm_app/presentation/widgets/hr_payroll/payslip_approval_history_list.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRManageEmployeeScreen extends StatefulWidget {
  final int? initialTabIndex;

  const HRManageEmployeeScreen({super.key, this.initialTabIndex});

  @override
  State<HRManageEmployeeScreen> createState() => _HRManageEmployeeScreenState();
}

class _HRManageEmployeeScreenState extends State<HRManageEmployeeScreen>
    with TickerProviderStateMixin {
  late AnimationController _listAnimationController;
  late TabController _tabController;
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );

    _searchController = TextEditingController();
    _searchController.addListener(() {});

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final currentIndex = _tabController.index;
        if (currentIndex == 1) {
          _loadPayslipData(forceRefresh: true);
        } else if (currentIndex == 0) {
          _fetchEmployees();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEmployees(animate: true);

      _loadPayslipData(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HRManageEmployeeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_tabController.length != 3) {
      _tabController.dispose();
      _tabController = TabController(length: 3, vsync: this);
    }
  }

  Future<void> _loadPayslipData({bool forceRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    if (authProvider.token != null) {
      try {
        await Future.wait([
          hrProvider.loadPayslipRequests(
            authProvider.token!,
            limit: 100,
            forceRefresh: forceRefresh,
          ),
          hrProvider.loadPayslipApprovalHistory(authProvider.token!),
        ]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load payslip requests: ${e.toString()}'),
              backgroundColor: AppColors.edgeError,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {}
  }

  Future<void> _fetchEmployees({bool animate = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    if (authProvider.token != null) {
      await hrProvider.fetchEmployees(authProvider.token!);
      if (animate && mounted) {
        _listAnimationController.forward(from: 0.0);
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.token != null) {
          final hrProvider = Provider.of<HRProvider>(context, listen: false);
          hrProvider.fetchEmployees(
            authProvider.token!,
            search: query.isEmpty ? null : query,
          );
        }
      }
    });
  }

  void _showCreateEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => HRCreateNewEmployee(
        onEmployeeCreated: () {
          _fetchEmployees(animate: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hrProvider = Provider.of<HRProvider>(context);
    final List<dynamic> allEmployees = hrProvider.employees;

    final List<dynamic> filteredEmployees;
    if (_searchQuery.isEmpty) {
      filteredEmployees = allEmployees;
    } else {
      filteredEmployees = allEmployees.where((employeeMap) {
        try {
          final employeeName = Employee.fromJson(
            employeeMap as Map<String, dynamic>,
          ).name.toLowerCase();
          return employeeName.contains(_searchQuery.toLowerCase());
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              color: AppColors.edgeSurface,
              child: TabBar(
                key: const ValueKey('employee_management_tabs'),
                controller: _tabController,
                indicatorColor: AppColors.edgePrimary,
                labelColor: AppColors.edgePrimary,
                unselectedLabelColor: AppColors.edgeTextSecondary,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  const Tab(icon: Icon(Icons.people, size: 20), text: 'Employees'),
                  const Tab(
                    icon: Icon(Icons.request_page, size: 20),
                    text: 'Payslip Requests',
                  ),
                  const Tab(icon: Icon(Icons.history, size: 20), text: 'History'),
                ],
              ),
            ),

            Container(height: 1, color: AppColors.edgeDivider),

            Expanded(
              child: TabBarView(
                key: const ValueKey('employee_management_tabview'),
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      Container(
                        color: AppColors.edgeSurface,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: HREmployeeSearchField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          hintText: 'Search employees by name, email, or ID...',
                        ),
                      ),
                      Container(height: 1, color: AppColors.edgeDivider),

                      Expanded(
                        child: hrProvider.isLoading
                            ? _buildLoadingState()
                            : hrProvider.error != null
                            ? _buildErrorState(hrProvider.error!)
                            : RefreshIndicator(
                                onRefresh: () => _fetchEmployees(animate: true),
                                color: AppColors.edgePrimary,
                                strokeWidth: 2.5,
                                child: filteredEmployees.isEmpty
                                    ? _buildEmptyState()
                                    : _buildEmployeeGrid(filteredEmployees),
                              ),
                      ),
                    ],
                  ),

                  Consumer<HRProvider>(
                    builder: (context, hrProvider, child) {
                      if (hrProvider.payslipRequests.isEmpty &&
                          !hrProvider.isLoading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _loadPayslipData(forceRefresh: true);
                        });
                      }

                      return RefreshIndicator(
                        onRefresh: () => _loadPayslipData(forceRefresh: true),
                        color: AppColors.edgePrimary,
                        child: PayslipRequestsList(
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
                                  _loadPayslipData(forceRefresh: true);
                                } catch (e) {}
                              },
                        ),
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
                          } catch (e) {}
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEmployeeDialog,
        backgroundColor: AppColors.edgePrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: AppColors.edgePrimary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.edgeError.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.edgeError,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load employees',
              style: TextStyle(
                color: AppColors.edgeText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.edgeTextSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => _fetchEmployees(animate: true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.edgePrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(
                    color: AppColors.edgePrimary,
                    width: 1,
                  ),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off
                        : Icons.people_outline,
                    size: 40,
                    color: AppColors.edgePrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No employees found'
                      : 'No employees available',
                  style: const TextStyle(
                    color: AppColors.edgeText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Try adjusting your search criteria'
                      : 'Employees will appear here once added',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.edgeTextSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreateEmployeeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Employee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.edgePrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeGrid(List<dynamic> employees) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: employees.length,
      itemBuilder: (ctx, i) {
        final employeeMap = employees[i] as Map<String, dynamic>;

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval((i * 0.05).clamp(0.0, 1.0), 1.0),
            ),
          ),
          child: HREmployeeListCard(
            key: ValueKey(employeeMap['_id']),
            employee: employeeMap,
            index: i,
            onViewProfile: () async {
              final employee = Employee.fromJson(employeeMap);
              final refreshed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) =>
                      HREmployeeManagementScreen(employee: employee),
                ),
              );
              if (refreshed == true) {
                _fetchEmployees();
              }
            },
            onViewEODs: () {
              final employee = Employee.fromJson(employeeMap);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HREodViewerPage(employee: employee),
                ),
              );
            },
            onViewPayroll: () {
              final employee = Employee.fromJson(employeeMap);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HRPayrollPage(employee: employee),
                ),
              );
            },
            onManageLeaves: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      HRLeaveManagementPage(employee: employeeMap),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

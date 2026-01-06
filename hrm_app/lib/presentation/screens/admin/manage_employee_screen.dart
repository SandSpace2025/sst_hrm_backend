import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/employee_model.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/create_new_employee.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/employee_list_card.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/employee_search_field.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/read_update_delete_employee_widget.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/role_toggle_switch.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/sub_pages/eod_viewer_page.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/manage_employees/sub_pages/admin_payroll_viewer_page.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_loading_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_empty_state.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen>
    with TickerProviderStateMixin {
  bool _isHrSelected = true;
  late AnimationController _listAnimationController;
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers(animate: true);
    });
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({bool animate = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final role = _isHrSelected ? 'hr' : 'employee';

    if (authProvider.token != null) {
      await adminProvider.fetchUsersByRole(role, authProvider.token!);
      if (animate && mounted) {
        _listAnimationController.forward(from: 0.0);
      }
    }
  }

  void _onToggle(bool isHr) {
    _triggerHaptic();
    setState(() {
      _isHrSelected = isHr;
      _searchController.clear();
    });
    _fetchUsers(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final List<dynamic> allUsers = adminProvider.users;

    final List<dynamic> filteredUsers;
    if (_searchQuery.isEmpty) {
      filteredUsers = allUsers;
    } else {
      filteredUsers = allUsers.where((userMap) {
        try {
          final employeeName = Employee.fromJson(
            userMap as Map<String, dynamic>,
          ).name.toLowerCase();
          return employeeName.contains(_searchQuery.toLowerCase());
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.edgeSurface,
        floatingActionButton: _buildEnhancedFAB(),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.edgeSurface,
                border: const Border(
                  bottom: BorderSide(color: AppColors.edgeDivider, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.edgeText.withValues(alpha: 13),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  EmployeeSearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                  ),
                  const SizedBox(height: 16),
                  RoleToggleSwitch(
                    isHrSelected: _isHrSelected,
                    onToggle: _onToggle,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: AppColors.edgeSurface,
                child: adminProvider.isLoading
                    ? const Center(
                        child: CustomLoadingState(
                          message: 'Loading employees...',
                        ),
                      )
                    : adminProvider.error != null
                    ? CustomErrorState(
                        message: adminProvider.error!,
                        onRetry: () {
                          _triggerHaptic();
                          _fetchUsers(animate: true);
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchUsers(animate: true),
                        color: AppColors.edgePrimary,
                        strokeWidth: 2.5,
                        child: filteredUsers.isEmpty
                            ? Center(
                                child: CustomEmptyState(
                                  title: _searchQuery.isNotEmpty
                                      ? 'No employees found'
                                      : 'No employees available',
                                  subtitle: _searchQuery.isNotEmpty
                                      ? 'Try adjusting your search criteria'
                                      : 'Employees will appear here once added',
                                  icon: _searchQuery.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.people_outline_rounded,
                                ),
                              )
                            : _buildUserGrid(filteredUsers),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrid(List<dynamic> filteredUsers) {
    return GridView.builder(
      key: ValueKey(_isHrSelected),
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: filteredUsers.length,
      itemBuilder: (ctx, i) {
        final userMap = filteredUsers[i] as Map<String, dynamic>;
        final employee = Employee.fromJson(userMap);

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval(
                (i * 0.05).clamp(0.0, 1.0),
                1.0,
                curve: _animCurve,
              ),
            ),
          ),
          child: AnimatedEmployeeListCard(
            key: ValueKey(employee.id),
            employee: employee,
            index: i,
            onViewProfile: () async {
              _triggerHaptic();
              final refreshed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) =>
                      EmployeeManagementScreen(employee: employee),
                ),
              );
              if (refreshed == true) {
                _fetchUsers();
              }
            },
            onViewEODs: () {
              _triggerHaptic();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EodViewerScreen(employee: employee),
                ),
              );
            },
            onViewPayroll: () {
              _triggerHaptic();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AdminPayrollViewerPage(employee: employee),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEnhancedFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgePrimary.withValues(alpha: 13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.edgePrimary.withValues(alpha: 25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          _triggerHaptic();
          _showCreateEmployeeDialog();
        },
        backgroundColor: AppColors.edgePrimary,
        foregroundColor: AppColors.edgeSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: const Text(
          'Add Employee',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  void _showCreateEmployeeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateUserScreen(
          onUserCreated: () {
            _fetchUsers(animate: true);
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hrm_app/core/services/notification_navigation_service.dart';
import 'package:hrm_app/presentation/providers/eod_provider.dart';
import 'package:hrm_app/presentation/providers/network_provider.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/attendance_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hrm_app/presentation/widgets/common/custom_bottom_nav_bar.dart';
import 'package:hrm_app/presentation/widgets/dashboard/attendance_clock_card.dart';
import 'package:hrm_app/presentation/widgets/dashboard/activity_grid_item.dart';
import 'package:hrm_app/presentation/widgets/dashboard/announcement_card.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hrm_app/presentation/widgets/employee_dashboard/employee_dashboard_skeleton.dart';

// Screens for other tabs
import 'package:hrm_app/presentation/widgets/attendance/history_calendar.dart';
import 'package:hrm_app/presentation/screens/employee/employee_eod_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_profile_screen.dart';
import 'package:hrm_app/presentation/screens/employee/employee_payslip_screen.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';

import 'package:hrm_app/presentation/screens/employee/employee_activity_screen.dart';

// Common
import 'package:hrm_app/presentation/widgets/common/announcement_preview_dialog.dart';
import 'package:hrm_app/presentation/widgets/common/notification_icon_button.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Trigger initial auth check and notification permission
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
      _fetchData(forceRefresh: true);
      NotificationNavigationService().consumePendingNavigation(context);
    });
  }

  Future<void> _checkNotificationPermission() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {}
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (_isRefreshing) return;
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeProvider = Provider.of<EmployeeProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        employeeProvider.setUserRole(authProvider.role ?? 'employee');
        final eodProvider = Provider.of<EODProvider>(context, listen: false);

        await Future.wait([
          employeeProvider.refreshAllData(
            authProvider.token!,
            forceRefresh: forceRefresh,
          ),
          eodProvider.loadTodayEOD(authProvider.token!),
          Provider.of<AttendanceProvider>(
            context,
            listen: false,
          ).loadAttendance(),
        ]);
      }
    } catch (e) {
      if (mounted) {
        // Handle error quietly
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    employeeProvider.clearData();
    await authProvider.logout(context);

    if (mounted) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _onNavItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 && !_isRefreshing) {
      _fetchData();
    }
  }

  // --- Data Helpers ---

  bool _shouldShowEOD(EmployeeProvider employeeProvider) {
    final subOrg = employeeProvider.employeeProfile?.subOrganisation;
    return subOrg != 'AO' && subOrg != 'Academic Overseas';
  }

  String _getLeaveBalanceValue(EmployeeProvider employeeProvider) {
    final leaveBalance = employeeProvider.leaveBalance;
    final dashboardData = employeeProvider.dashboardData;

    // Try to get casual leave from the correct nested path
    if (leaveBalance != null && leaveBalance['leaveBalance'] != null) {
      final casualLeave = leaveBalance['leaveBalance']['casualLeave'];
      if (casualLeave != null) {
        if (casualLeave is num) return '${casualLeave.toInt()}';
        if (casualLeave is String) {
          final parsed = int.tryParse(casualLeave);
          if (parsed != null) return '$parsed';
        }
      }
    }

    // Fallback to dashboard data
    if (dashboardData != null && dashboardData['leaveBalance'] != null) {
      final casualLeave = dashboardData['leaveBalance']['casualLeave'];
      if (casualLeave != null) {
        if (casualLeave is num) return '${casualLeave.toInt()}';
        if (casualLeave is String) {
          final parsed = int.tryParse(casualLeave);
          if (parsed != null) return '$parsed';
        }
      }
    }

    return '0';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes';
  }

  // --- Widget Builders ---

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final employeeProvider = Provider.of<EmployeeProvider>(context);

    if (authProvider.token == null || authProvider.role != 'employee') {
      // Simple redirect or loading if state is inconsistent
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor:
          Colors.white, // Ensure clean white background as per design
      body: Stack(
        children: [
          // Background Gradient Overlay (Subtle)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [Expanded(child: _buildBody(employeeProvider))],
            ),
          ),

          // Floating Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: CustomBottomNavBar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onNavItemSelected,
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EmployeeProvider employeeProvider) {
    if (_selectedIndex == 0) {
      return _buildDashboardContent(employeeProvider);
    } else if (_selectedIndex == 1) {
      return HistoryCalendar(onBack: () => _onNavItemSelected(0));
    } else if (_selectedIndex == 2) {
      return const EmployeePayslipScreen();
    } else if (_selectedIndex == 3) {
      return const EmployeeProfileScreen();
    } else {
      return _buildDashboardContent(employeeProvider);
    }
  }

  Widget _buildDashboardContent(EmployeeProvider employeeProvider) {
    if (employeeProvider.isLoading && employeeProvider.dashboardData == null) {
      return const EmployeeDashboardSkeleton();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ), // Ensure scrollability for RefreshIndicator
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(employeeProvider),
            const SizedBox(height: 32),

            // 2. Attendance Section
            _buildAttendanceSection(),
            const SizedBox(height: 32),

            // 3. Employee Activity Grid
            _buildActivitySection(employeeProvider),
            const SizedBox(height: 32),

            // 4. Announcements
            _buildAnnouncementsSection(employeeProvider),
            const SizedBox(height: 80), // Extra scroll space
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final networkProvider = Provider.of<NetworkProvider>(
      context,
      listen: false,
    );
    final isOnline = await networkProvider.checkConnection();

    if (!isOnline) {
      SnackBarUtils.showWarning(context, 'No Internet Connection');
      return;
    }

    await _fetchData(forceRefresh: true);
  }

  Widget _buildHeader(EmployeeProvider provider) {
    final name = provider.employeeProfile?.name.split(' ').first ?? 'Employee';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hey $name!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Good morning! mark your attendance',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Employee',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const NotificationIconButton(),
      ],
    );
  }

  Widget _buildAttendanceSection() {
    return Consumer<AttendanceProvider>(
      builder: (context, attendance, child) {
        return Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AttendanceClockCard(
              isCheckedIn: attendance.isClockedIn,
              checkInTime: attendance.clockInTime != null
                  ? DateFormat('hh:mm').format(attendance.clockInTime!)
                  : '--:--',
              checkOutTime: attendance.clockOutTime != null
                  ? DateFormat('hh:mm').format(attendance.clockOutTime!)
                  : '--:--',
              totalHours: _formatDuration(attendance.workedDuration),
              onCheckIn: !attendance.isClockedIn && !attendance.isLoading
                  ? () => attendance.punchAction()
                  : null,
              onCheckOut: attendance.isClockedIn && !attendance.isLoading
                  ? () => attendance.punchAction()
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivitySection(EmployeeProvider provider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeActivityScreen(),
                  ),
                );
              },
              child: const Text(
                'Employee Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeActivityScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85, // Adjust for card height
          children: [
            _buildActivityGridItem(
              title: 'Pending EOD',
              subtitle: "Submit today's report",
              value:
                  '${context.watch<EODProvider>().todayEOD == null && _shouldShowEOD(provider) ? "1" : "0"}',
              icon: FontAwesomeIcons.clipboardCheck,
              onTap: () {
                final showEOD = _shouldShowEOD(provider);
                if (showEOD) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeEODScreen(),
                    ),
                  );
                }
              },
            ),
            _buildActivityGridItem(
              title: 'Available Leaves',
              subtitle: 'Total Number of Days',
              value: _getLeaveBalanceValue(provider),
              icon: FontAwesomeIcons.calendarDay,
              onTap: null, // Non-clickable info card
            ),
            _buildActivityGridItem(
              title: 'Unread Messages',
              subtitle: 'New notifications',
              value: '${provider.unreadMessagesCount}',
              icon: FontAwesomeIcons.solidCommentDots,
              customColor: AppColors.backgroundSecondary,
              onTap: provider.unreadMessagesCount > 0
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployeeActivityScreen(),
                        ),
                      );
                    }
                  : null, // Only clickable when there are unread messages
            ),
            _buildActivityGridItem(
              title: 'Requested Leaves',
              subtitle: 'Awaiting approval',
              value:
                  '${provider.dashboardData?['pendingLeavesCount'] ?? provider.dashboardData?['pendingLeaves'] ?? 0}',
              icon: FontAwesomeIcons.fileSignature,
              customColor: AppColors.backgroundSecondary,
              onTap: null, // Non-clickable info card
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityGridItem({
    required String title,
    required String subtitle,
    required String? value,
    required IconData icon,
    VoidCallback? onTap,
    Color? customColor,
  }) {
    return ActivityGridItem(
      title: title,
      subtitle: subtitle,
      value: value,
      customColor: customColor,
      icon: FaIcon(
        icon,
        size: 90,
        color: AppColors.primary.withValues(alpha: 0.25),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAnnouncementsSection(EmployeeProvider provider) {
    // Filter logic similar to original
    List<dynamic> announcements = provider.announcements;
    if (announcements.isEmpty && provider.dashboardData != null) {
      final dashboardAnnouncements =
          provider.dashboardData!['recentAnnouncements'];
      if (dashboardAnnouncements is List) {
        announcements = dashboardAnnouncements;
      }
    }

    // Take top 3
    final recentAnnouncements = announcements.take(3).toList();

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '(Today)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recentAnnouncements.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No recent announcements'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentAnnouncements.length,
            itemBuilder: (context, index) {
              final item = recentAnnouncements[index];
              // Safe parsing
              final map = item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{};
              final title = map['title'] ?? 'Announcement';
              final priority = map['priority'] ?? 'normal';

              String author = 'Admin & HR';
              if (map['createdBy'] != null) {
                if (map['createdBy'] is Map) {
                  final createdBy = Map<String, dynamic>.from(map['createdBy']);
                  author =
                      createdBy['fullName'] ??
                      createdBy['name'] ??
                      'Admin & HR';
                } else if (map['createdBy'] is String) {
                  author = map['createdBy'];
                }
              }

              return AnnouncementCard(
                title: title,
                subtitle: 'By $author',
                priority: priority.toString(),
                onTap: () {
                  showAnnouncementPreview(context, map);
                },
              );
            },
          ),
      ],
    );
  }
}

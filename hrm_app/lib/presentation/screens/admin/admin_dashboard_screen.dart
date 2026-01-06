import 'package:flutter/material.dart';
import 'package:hrm_app/core/services/notification_navigation_service.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/presentation/providers/network_provider.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:hrm_app/presentation/screens/admin/admin_announcement_screen.dart';
import 'package:hrm_app/presentation/screens/admin/admin_profile_screen.dart';
import 'package:hrm_app/presentation/screens/admin/leave_request_screen.dart';
import 'package:hrm_app/presentation/screens/admin/messaging_screen.dart';
import 'package:hrm_app/presentation/screens/admin/manage_employee_screen.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/admin_dash_board/admin_collapsable_navbar.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/admin_dash_board/admin_summary_cards_widget.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/admin_dash_board/recent_activity_widget.dart';
import 'package:hrm_app/presentation/widgets/common/dashboard_header.dart';
import 'package:hrm_app/presentation/widgets/common/dialogs/logout_confirmation_dialog.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/admin_dash_board/admin_dashboard_skeleton.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _navAnimationController;
  late AnimationController _contentAnimationController;
  int _selectedIndex = 0;
  bool _isNavOpen = false;

  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _navAnimationController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );
    _contentAnimationController = AnimationController(
      vsync: this,
      duration: _animDuration,
    );

    Future<void> checkNotificationPermission() async {
      try {
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }
      } catch (e) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkNotificationPermission();
      _fetchData(forceRefresh: true);
      _setupWebSocketConnection();
      _contentAnimationController.forward();
      NotificationNavigationService().consumePendingNavigation(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Removed _fetchData() from here to prevent infinite loop.
    // Data is already fetched in initState.
  }

  @override
  void dispose() {
    _navAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final networkProvider = Provider.of<NetworkProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      try {
        final adminProvider = Provider.of<AdminProvider>(
          context,
          listen: false,
        );

        adminProvider.setUserRole(authProvider.role ?? 'admin');

        if (forceRefresh) {
          final connectivity = await Connectivity().checkConnectivity();
          final isOnline =
              connectivity.isNotEmpty &&
              connectivity.any((result) => result != ConnectivityResult.none);

          if (!isOnline && !networkProvider.isOnline) {
            if (mounted) {
              SnackBarUtils.showError(context, 'No internet connection');
            }
            return;
          } else if (isOnline) {
            if (mounted) {
              SnackBarUtils.showInfo(context, 'Refreshing dashboard...');
            }
          }
        }

        final connectivity = await Connectivity().checkConnectivity();
        final isOnline =
            connectivity.isNotEmpty &&
            connectivity.any((result) => result != ConnectivityResult.none);

        if (isOnline || forceRefresh) {
          await adminProvider.refreshAllData(
            authProvider.token!,
            forceRefresh: forceRefresh,
          );
        }

        if (forceRefresh && adminProvider.error == null) {
          if (mounted) {
            SnackBarUtils.showSuccess(context, 'Dashboard refreshed');
          }
        }
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (!errorMsg.contains('socketexception') &&
            !errorMsg.contains('no internet connection') &&
            !errorMsg.contains('network')) {
          if (mounted) {
            SnackBarUtils.showError(context, 'Failed to load dashboard: $e');
          }
        }
      }
    }
  }

  Future<void> _setupWebSocketConnection() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final webSocketProvider = Provider.of<WebSocketProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      try {
        final payload = Jwt.parseJwt(authProvider.token!);
        final userId = payload['userId'] ?? payload['id'];

        if (userId != null) {
          await webSocketProvider.connect(
            authProvider.token!,
            userId.toString(),
            authProvider.role ?? 'admin',
          );
        }
      } catch (e) {}
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final webSocketProvider = Provider.of<WebSocketProvider>(
      context,
      listen: false,
    );

    adminProvider.clearData();

    await webSocketProvider.disconnect();
    await authProvider.logout(context);

    if (mounted) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      if (index == 0) {
        _fetchData();
      }
    }
    if (_isNavOpen) {
      _toggleNav();
    }
  }

  void _toggleNav() {
    setState(() {
      _isNavOpen = !_isNavOpen;
      if (_isNavOpen) {
        _navAnimationController.forward();
      } else {
        _navAnimationController.reverse();
      }
    });
  }

  Widget _animatedWidget({required Widget child, required double interval}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _contentAnimationController,
          curve: Interval(interval, 1.0, curve: _animCurve),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _contentAnimationController,
                curve: Interval(interval, 1.0, curve: _animCurve),
              ),
            ),
        child: child,
      ),
    );
  }

  Widget _buildNotificationSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.edgeSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.edgeDivider, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 0
                    ? 'All up to date'
                    : count == 1
                    ? '1 item pending'
                    : '$count items pending',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.edgeTextSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageNotificationCard(Map<String, dynamic> message) {
    final senderName =
        message['sender']?['name'] ??
        message['sender']?['fullName'] ??
        'Unknown';
    final content = message['content'] ?? '';
    final timestamp = message['createdAt'] ?? '';
    final messageId = message['_id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () => _navigateToChat(message),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.edgePrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message from $senderName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content.length > 50
                            ? '${content.substring(0, 50)}...'
                            : content,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.edgeTextSecondary,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.edgeTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _markMessageAsRead(messageId),
                  icon: const Icon(
                    Icons.done_all,
                    color: AppColors.edgePrimary,
                    size: 20,
                  ),
                  tooltip: 'Mark as read',
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.edgeTextSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildLeaveRequestNotificationCard(Map<String, dynamic> leaveRequest) {
    final employeeName = leaveRequest['employeeName'] ?? 'Unknown Employee';
    final leaveType = leaveRequest['leaveType'] ?? 'Leave';
    final startDate = leaveRequest['startDate'] ?? '';
    final endDate = leaveRequest['endDate'] ?? '';
    final reason = leaveRequest['reason'] ?? '';
    final isEmergency = leaveRequest['isEmergency'] ?? false;

    // Format date range
    String dateRange = '';
    try {
      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        final start = DateTime.parse(startDate);
        final end = DateTime.parse(endDate);
        if (start.day == end.day &&
            start.month == end.month &&
            start.year == end.year) {
          dateRange = '${start.day}/${start.month}/${start.year}';
        } else {
          dateRange =
              '${start.day}/${start.month} - ${end.day}/${end.month}/${end.year}';
        }
      }
    } catch (e) {
      dateRange = 'Invalid date';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            // Navigate to leave requests screen
            setState(() => _selectedIndex = 3);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.edgeWarning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isEmergency
                        ? Icons.priority_high
                        : Icons.event_note_outlined,
                    color: isEmergency
                        ? AppColors.edgeError
                        : AppColors.edgeWarning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$leaveType request from $employeeName',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.edgeText,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (isEmergency)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.edgeError,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $dateRange',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.edgeTextSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          reason.length > 50
                              ? '${reason.substring(0, 50)}...'
                              : reason,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.edgeTextSecondary,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.edgeTextSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(Map<String, dynamic>? dashboardData) {
    final adminProvider = Provider.of<AdminProvider>(context);
    final unreadMessages = adminProvider.unreadMessagesCount;
    final unreadMessagesData = dashboardData?['unreadMessagesData'] ?? [];
    final pendingLeaves = dashboardData?['pendingLeaveApprovals'] ?? 0;
    final pendingLeavesData = dashboardData?['pendingLeaveRequestsData'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
                letterSpacing: -0.5,
              ),
            ),
            if (unreadMessages > 0 || pendingLeaves > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.edgeError,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${unreadMessages + pendingLeaves}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Summary Cards Row
        Row(
          children: [
            Expanded(
              child: _buildNotificationSummaryCard(
                title: 'Unread Messages',
                count: unreadMessages,
                icon: Icons.message_outlined,
                color: AppColors.edgeError,
                onTap: () => setState(() => _selectedIndex = 4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNotificationSummaryCard(
                title: 'Pending Leaves',
                count: pendingLeaves,
                icon: Icons.event_note_outlined,
                color: AppColors.edgeWarning,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Detailed Notifications
        if (unreadMessages > 0 || pendingLeaves > 0) ...[
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Unread Messages - Show detailed notifications
          if (unreadMessages > 0) ...[
            ...unreadMessagesData
                .take(3) // Show only first 3 messages
                .map<Widget>(
                  (message) => _buildMessageNotificationCard(message),
                )
                .toList(),
          ],

          if (unreadMessages > 0 && pendingLeaves > 0)
            const SizedBox(height: 12),

          // Pending Leave Approvals - Show detailed notifications
          if (pendingLeaves > 0) ...[
            ...pendingLeavesData
                .take(3) // Show only first 3 leave requests
                .map<Widget>(
                  (leaveRequest) =>
                      _buildLeaveRequestNotificationCard(leaveRequest),
                )
                .toList(),
          ],
        ] else ...[
          // All caught up state
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.edgeAccent,
                  size: 32,
                ),
                SizedBox(height: 12),
                Text(
                  'All caught up!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'No pending messages or leave requests',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final pageTitles = [
      'Dashboard',
      'Announcements',
      'Leave Requests',
      'Manage Team',
      'Messages',
      'Profile',
    ];
    final List<Widget> pages = <Widget>[
      _buildHomeTabContent(),
      const AnnouncementsPage(),
      const LeaveRequestScreen(),
      const ManageEmployeesScreen(),
      const MessagingScreen(),
      const AdminProfileScreen(),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.edgeBackground,
              AppColors.edgeBackground.withValues(alpha: 242),
              AppColors.edgePrimary.withValues(alpha: 5),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.edgePrimary.withValues(alpha: 8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.edgePrimary.withValues(alpha: 5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                DashboardHeader(
                  title: pageTitles[_selectedIndex],
                  userName: 'Admin',
                  userRole: authProvider.role?.toUpperCase() ?? 'ADMIN',
                  onMenuTap: _toggleNav,
                  menuAnimation: _navAnimationController,
                ),
                Expanded(child: pages[_selectedIndex]),
              ],
            ),

            if (_isNavOpen)
              GestureDetector(
                onTap: _toggleNav,
                child: AnimatedBuilder(
                  animation: _navAnimationController,
                  builder: (context, child) => Container(
                    color: Colors.black.withValues(
                      alpha: 102 * _navAnimationController.value,
                    ),
                  ),
                ),
              ),

            AnimatedPositioned(
              duration: _animDuration,
              curve: _animCurve,
              left: _isNavOpen ? 0 : -280,
              top: 0,
              bottom: 0,
              width: 280,
              child: Consumer<AdminProvider>(
                builder: (context, adminProvider, child) {
                  return SafeArea(
                    child: CollapsibleSideNav(
                      selectedIndex: _selectedIndex,
                      onItemTapped: _onItemTapped,
                      onLogout: () => LogoutConfirmationDialog.show(
                        context,
                        onLogout: _handleLogout,
                      ),
                      userName: 'Admin',
                      userRole: authProvider.role?.toUpperCase() ?? 'ADMIN',
                      adminProfile: adminProvider.adminProfile,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildHomeTabContent() {
    bool isSmallDevice() => MediaQuery.of(context).size.width < 360;
    final adminProvider = Provider.of<AdminProvider>(context);
    final dashboardData = adminProvider.dashboardData;

    if (adminProvider.isLoading && dashboardData == null) {
      return const AdminDashboardSkeleton();
    }

    if (adminProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CustomErrorState(
            message: adminProvider.error!,
            onRetry: () => _fetchData(forceRefresh: true),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchData(forceRefresh: true),
      color: AppColors.edgePrimary,
      strokeWidth: 2.5,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallDevice() ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SummaryCards(
                isSmallDevice: isSmallDevice(),
                animatedWidget: _animatedWidget,
              ),
              const SizedBox(height: 20),

              _animatedWidget(
                child: _buildNotificationsSection(dashboardData),
                interval: 0.15,
              ),
              const SizedBox(height: 20),

              const RecentActivityWidget(),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToChat(Map<String, dynamic> message) {
    setState(() => _selectedIndex = 4);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        await _fetchData();
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Message marked as read');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to mark message as read: $e');
      }
    }
  }
}

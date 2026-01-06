import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/services/notification_navigation_service.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/network_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/screens/hr/hr_announcement_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_profile_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_messaging_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_manage_employee_screen.dart';
import 'package:hrm_app/presentation/screens/hr/hr_leave_request_screen.dart';
import 'package:hrm_app/presentation/screens/auth/login_screen.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/hr_dash_board/hr_collapsable_navbar.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/employee_count_card.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/recent_announcements.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/hr_dashboard/hr_dashboard_skeleton.dart';
import 'package:hrm_app/core/services/websocket_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

const edgeBorder = Color(0xFFEDEBE9);

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _navAnimationController;
  late AnimationController _contentAnimationController;
  int _selectedIndex = 0;
  bool _isNavOpen = false;
  StreamSubscription<Map<String, dynamic>>? _unreadMessagesSubscription;
  static const Duration _animDuration = Duration(milliseconds: 250);
  static const Curve _animCurve = Curves.easeOutCubic;

  Future<void> _checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isProvisional) {
        await Permission.notification.request();
      }
    } catch (e) {}
  }

  void _setupUnreadMessagesListener() {
    try {
      final webSocketService = WebSocketService();
      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      _unreadMessagesSubscription = webSocketService.messageStream.listen((
        data,
      ) {
        try {
          final payloadRaw = data['data'] ?? data;
          Map<String, dynamic> payload = Map<String, dynamic>.from(
            (payloadRaw is Map<String, dynamic>) ? payloadRaw : {},
          );

          if (payload.containsKey('message') && payload['message'] is Map) {
            payload = Map<String, dynamic>.from(payload['message'] as Map);
          }

          final event = (data['event'] ?? data['eventType'] ?? '').toString();
          final looksLikeMessage =
              payload.containsKey('messageId') ||
              payload.containsKey('sender') ||
              payload.containsKey('receiver') ||
              payload.containsKey('content');

          if (!looksLikeMessage) return;

          String? receiverModel;
          String? receiverId;

          if (payload['receiver'] is Map) {
            final r = payload['receiver'] as Map;
            receiverId = (r['_id'] ?? r['id'] ?? r['userId'])?.toString();
            receiverModel = (r['userType'] ?? r['model'])?.toString();
          } else {
            receiverId = payload['receiver']?.toString();
          }
          receiverModel ??= payload['receiverModel']?.toString();

          if (receiverModel != null && receiverModel.toLowerCase() == 'hr') {
            final currentHRId = hrProvider.hrProfile?.id;
            if (currentHRId != null && receiverId == currentHRId) {
              final currentChatPartnerId = hrProvider.currentChatPartnerId;
              String? senderId;
              if (payload['sender'] is Map) {
                final s = payload['sender'] as Map;
                senderId = (s['_id'] ?? s['id'] ?? s['userId'])?.toString();
              } else {
                senderId = payload['sender']?.toString();
              }

              if (senderId != null && senderId != currentChatPartnerId) {
                hrProvider.addUnreadConversation(senderId);
              } else if (senderId == currentChatPartnerId) {}
            }
          }
        } catch (e) {}
      });
    } catch (e) {}
  }

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

    _navAnimationController.value = 0.0;
    _contentAnimationController.value = 0.0;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _checkNotificationPermission();
        await _fetchData(forceRefresh: false);
        _contentAnimationController.forward();
        _setupIntervalRefresh();
        _setupUnreadMessagesListener();
        NotificationNavigationService().consumePendingNavigation(context);
      } catch (e) {
        _contentAnimationController.forward();
        _setupUnreadMessagesListener();
        _setupIntervalRefresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _unreadMessagesSubscription?.cancel();
    _navAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  void _setupIntervalRefresh() {
    final hrProvider = Provider.of<HRProvider>(context, listen: false);
    hrProvider.setupWebSocketListeners(context);
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) return;

      final hrProvider = Provider.of<HRProvider>(context, listen: false);

      hrProvider.setUserRole(authProvider.role ?? 'hr');

      try {
        final networkProvider = Provider.of<NetworkProvider>(
          context,
          listen: false,
        );

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
          await hrProvider.refreshAllData(
            authProvider.token!,
            forceRefresh: forceRefresh,
          );
        } else {}

        if (forceRefresh && hrProvider.error == null) {
          if (mounted) {
            SnackBarUtils.showSuccess(context, 'Dashboard refreshed');
          }
        }
      } catch (networkError) {}
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

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    hrProvider.clearData();

    await authProvider.logout(context);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.edgeSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.edgeDivider.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.edgeText.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.edgeText,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          const Text(
                            'Are you sure you want to logout?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.edgeTextSecondary,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.edgeBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.edgeDivider.withOpacity(
                                        0.3,
                                      ),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.edgeText.withOpacity(
                                          0.05,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          Navigator.of(dialogContext).pop(),
                                      borderRadius: BorderRadius.circular(12),
                                      splashColor: AppColors.edgeTextSecondary
                                          .withOpacity(0.1),
                                      highlightColor: AppColors
                                          .edgeTextSecondary
                                          .withOpacity(0.05),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'Cancel',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.edgeTextSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.edgeError,
                                        AppColors.edgeError.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.edgeError.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(dialogContext).pop();
                                        _handleLogout();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      splashColor: Colors.white.withOpacity(
                                        0.1,
                                      ),
                                      highlightColor: Colors.white.withOpacity(
                                        0.05,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
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
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final pageTitles = [
      'Dashboard',
      'Announcements',
      'Leave Requests',
      'Manage Employees',
      'Message',
      'Profile',
    ];
    final List<Widget> pages = <Widget>[
      _buildHomeTabContent(),
      const HRAnnouncementScreen(),
      const HRLeaveRequestScreen(),
      const HRManageEmployeeScreen(),
      const HRMessagingScreen(),
      const HRProfileScreen(),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.edgeBackground,
              AppColors.edgeBackground.withOpacity(0.95),
              AppColors.edgePrimary.withOpacity(0.02),
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
                      AppColors.edgePrimary.withOpacity(0.03),
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
                      AppColors.edgePrimary.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                _buildEnhancedHeader(pageTitles[_selectedIndex]),
                Expanded(child: pages[_selectedIndex]),
              ],
            ),

            if (_isNavOpen)
              GestureDetector(
                onTap: _toggleNav,
                child: AnimatedBuilder(
                  animation: _navAnimationController,
                  builder: (context, child) => Container(
                    color: Colors.black.withOpacity(
                      0.4 * _navAnimationController.value,
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
              child: Consumer<HRProvider>(
                builder: (context, hrProvider, child) {
                  return SafeArea(
                    child: HRCollapsableNavbar(
                      selectedIndex: _selectedIndex,
                      onItemSelected: _onItemTapped,
                      onLogout: _showLogoutConfirmationDialog,
                      userName: hrProvider.hrProfile?.name ?? 'HR',
                      userRole:
                          authProvider.role?.toUpperCase() ?? 'HR MANAGER',
                      hrProfile: hrProvider.hrProfile,
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

  Widget _buildEnhancedHeader(String title) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.edgeDivider.withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleNav,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.edgePrimary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: AnimatedIcon(
                      icon: AnimatedIcons.menu_close,
                      progress: _navAnimationController,
                      color: AppColors.edgePrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.edgeText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Welcome back, HR',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'HR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgePrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTabContent() {
    bool isSmallDevice() => MediaQuery.of(context).size.width < 360;
    final hrProvider = Provider.of<HRProvider>(context);
    final dashboardData = hrProvider.dashboardData;

    if (hrProvider.isLoading && dashboardData == null) {
      return const HRDashboardSkeleton();
    }

    if (hrProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.edgeError.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgeText.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.edgeError.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.edgeError.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.edgeError,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unable to load data',
                  style: TextStyle(
                    color: AppColors.edgeText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hrProvider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.edgeTextSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.edgePrimary,
                        AppColors.edgePrimary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.edgePrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _fetchData(forceRefresh: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
              _animatedWidget(
                child: EmployeeCountCard(
                  dashboardData: dashboardData,
                  onMessageTap: () => setState(() => _selectedIndex = 4),
                  onPendingLeavesTap: () => setState(() => _selectedIndex = 2),
                ),
                interval: 0.0,
              ),
              const SizedBox(height: 20),

              _animatedWidget(
                child: RecentAnnouncements(dashboardData: dashboardData),
                interval: 0.2,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

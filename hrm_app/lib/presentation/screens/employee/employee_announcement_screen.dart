import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/send_announcements/recent_announcement_widget.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/data/models/announcement_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class EmployeeAnnouncementScreen extends StatefulWidget {
  const EmployeeAnnouncementScreen({super.key});

  @override
  State<EmployeeAnnouncementScreen> createState() =>
      _EmployeeAnnouncementScreenState();
}

class _EmployeeAnnouncementScreenState extends State<EmployeeAnnouncementScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 500);
  static const Curve _animCurve = Curves.easeOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
      _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _loadAnnouncements() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final employeeProvider = Provider.of<EmployeeProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      employeeProvider.loadAnnouncements(authProvider.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: AppColors.edgeSurface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(isSmallDevice),

                Expanded(child: _buildAnnouncementsContent(isSmallDevice)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallDevice) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 16 : 20,
        vertical: 12,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallDevice ? 16 : 20,
        vertical: isSmallDevice ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withValues(alpha: 10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withValues(alpha: 25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: AppColors.edgePrimary,
              size: isSmallDevice ? 20 : 24,
            ),
          ),
          SizedBox(width: isSmallDevice ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: isSmallDevice ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.edgeText,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Company updates and news',
                  style: TextStyle(
                    fontSize: isSmallDevice ? 11 : 12,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _triggerHaptic();
              _loadAnnouncements();
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.edgePrimary,
              size: isSmallDevice ? 20 : 24,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsContent(bool isSmallDevice) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        if (employeeProvider.isLoading &&
            employeeProvider.announcements.isEmpty) {
          return _buildLoadingState();
        }

        if (employeeProvider.error != null &&
            employeeProvider.announcements.isEmpty) {
          return _buildErrorState(employeeProvider.error!);
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
          child: employeeProvider.announcements.isEmpty
              ? _buildEmptyState()
              : RecentAnnouncementsList(
                  announcements: employeeProvider.announcements.map((
                    announcement,
                  ) {
                    if (announcement is Map<String, dynamic>) {
                      return AnnouncementModel.fromJson(announcement);
                    } else if (announcement is AnnouncementModel) {
                      return announcement;
                    } else {
                      return AnnouncementModel.fromJson(
                        announcement as Map<String, dynamic>,
                      );
                    }
                  }).toList(),
                  onRefresh: null,
                  isLoading: employeeProvider.isLoading,
                  hasMoreData: false,
                  onLoadMore: null,
                ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(5, (index) => ShimmerLoading.listItem()),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading announcements...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
            ),
          ),
        ],
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.edgeError,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load announcements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.edgeTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _triggerHaptic();
                _loadAnnouncements();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgePrimary,
                foregroundColor: AppColors.edgeSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withValues(alpha: 25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                size: 64,
                color: AppColors.edgePrimary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Announcements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.edgeText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no announcements at the moment.\nCheck back later for updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

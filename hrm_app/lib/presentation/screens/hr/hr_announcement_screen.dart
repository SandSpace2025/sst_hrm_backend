import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/hr_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/send_announcements/compose_announcement_widget.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/send_announcements/recent_announcement_widget.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import 'package:hrm_app/data/models/announcement_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRAnnouncementScreen extends StatefulWidget {
  const HRAnnouncementScreen({super.key});

  @override
  State<HRAnnouncementScreen> createState() => _HRAnnouncementScreenState();
}

class _HRAnnouncementScreenState extends State<HRAnnouncementScreen>
    with TickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 500);
  static const Duration _tabAnimDuration = Duration(milliseconds: 300);
  static const Curve _animCurve = Curves.easeOutCubic;
  static const Curve _tabAnimCurve = Curves.easeInOutCubic;

  late TabController _tabController;
  late PageController _pageController;
  late AnimationController _controller;
  late AnimationController _tabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _tabFadeAnimation;
  late Animation<Offset> _tabSlideAnimation;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController(initialPage: 0);
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: _tabAnimDuration,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _tabFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tabAnimationController, curve: _tabAnimCurve),
    );

    _tabSlideAnimation =
        Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _tabAnimationController,
            curve: _tabAnimCurve,
          ),
        );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: _tabAnimDuration,
          curve: _tabAnimCurve,
        );
        _tabAnimationController.forward();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnnouncements();
      _controller.forward();
      _tabAnimationController.forward();
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
    _tabController.dispose();
    _pageController.dispose();
    _controller.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _loadAnnouncements() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    if (authProvider.token != null) {
      hrProvider.loadAnnouncements(authProvider.token!, onlyMine: true);
    }
  }

  Future<void> _addAnnouncement(Map<String, dynamic> announcementData) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hrProvider = Provider.of<HRProvider>(context, listen: false);

    if (authProvider.token == null) return;

    try {
      await hrProvider.createAnnouncement(
        announcementData['title'],
        announcementData['message'],
        authProvider.token!,
        audience: announcementData['audience'],
        priority: announcementData['priority'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement sent successfully'),
            backgroundColor: AppColors.edgeAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        await hrProvider.loadAnnouncements(authProvider.token!, onlyMine: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hrProvider.error ?? 'Failed to send announcement'),
            backgroundColor: AppColors.edgeError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: AppColors.edgeSurface,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildCleanTabBar(isSmallDevice),

                  Expanded(
                    child: AnimatedBuilder(
                      animation: _tabAnimationController,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _tabFadeAnimation,
                          child: SlideTransition(
                            position: _tabSlideAnimation,
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (index) {
                                _tabController.animateTo(index);
                                _tabAnimationController.forward();
                              },
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildSendAnnouncementTab(isSmallDevice),
                                _buildPreviousAnnouncementsTab(isSmallDevice),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanTabBar(bool isSmallDevice) {
    return AnimatedBuilder(
      animation: _tabAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _tabSlideAnimation.value.dy * 10),
          child: Opacity(
            opacity: _tabFadeAnimation.value,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isSmallDevice ? 16 : 20),
              decoration: BoxDecoration(
                color: AppColors.edgeSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.edgeDivider, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.edgeText.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.edgePrimary,
                unselectedLabelColor: AppColors.edgeTextSecondary,
                indicatorColor: Colors.transparent,
                indicatorWeight: 0,
                indicator: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(
                  fontSize: isSmallDevice ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: isSmallDevice ? 13 : 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                tabs: [
                  Tab(
                    child: AnimatedContainer(
                      duration: _tabAnimDuration,
                      curve: _tabAnimCurve,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallDevice ? 12 : 16,
                        vertical: isSmallDevice ? 8 : 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: _tabAnimDuration,
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.send_rounded,
                              key: ValueKey('send_${_tabController.index}'),
                              size: isSmallDevice ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: isSmallDevice ? 6 : 8),
                          const Text('Send'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: AnimatedContainer(
                      duration: _tabAnimDuration,
                      curve: _tabAnimCurve,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallDevice ? 12 : 16,
                        vertical: isSmallDevice ? 8 : 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: _tabAnimDuration,
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              Icons.history_rounded,
                              key: ValueKey('history_${_tabController.index}'),
                              size: isSmallDevice ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: isSmallDevice ? 6 : 8),
                          const Text('History'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendAnnouncementTab(bool isSmallDevice) {
    return AnimatedBuilder(
      animation: _tabAnimationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _tabFadeAnimation,
          child: SlideTransition(
            position: _tabSlideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
              child: ComposeAnnouncementCard(onSend: _addAnnouncement),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviousAnnouncementsTab(bool isSmallDevice) {
    return Consumer<HRProvider>(
      builder: (context, hrProvider, child) {
        if (hrProvider.isLoading && hrProvider.announcements.isEmpty) {
          return AnimatedBuilder(
            animation: _tabAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _tabFadeAnimation,
                child: SlideTransition(
                  position: _tabSlideAnimation,
                  child: _buildLoadingState(),
                ),
              );
            },
          );
        }

        if (hrProvider.error != null && hrProvider.announcements.isEmpty) {
          return AnimatedBuilder(
            animation: _tabAnimationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _tabFadeAnimation,
                child: SlideTransition(
                  position: _tabSlideAnimation,
                  child: _buildErrorState(hrProvider.error!),
                ),
              );
            },
          );
        }

        return AnimatedBuilder(
          animation: _tabAnimationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _tabFadeAnimation,
              child: SlideTransition(
                position: _tabSlideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
                  child: RecentAnnouncementsList(
                    announcements: hrProvider.announcements
                        .map(
                          (announcement) =>
                              AnnouncementModel.fromJson(announcement),
                        )
                        .toList(),
                    onRefresh: null,
                    isLoading: hrProvider.isLoading,
                    hasMoreData: false,
                    onLoadMore: null,
                  ),
                ),
              ),
            );
          },
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
            ElevatedButton(
              onPressed: () {
                _triggerHaptic();
                _loadAnnouncements();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgePrimary,
                foregroundColor: AppColors.edgeSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

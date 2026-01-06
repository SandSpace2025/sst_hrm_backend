import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/hr_model.dart';
import 'package:hrm_app/core/constants/app_constants.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HRCollapsableNavbar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final String userName;
  final String userRole;
  final HR? hrProfile;

  const HRCollapsableNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
    required this.userName,
    required this.userRole,
    this.hrProfile,
  });

  @override
  State<HRCollapsableNavbar> createState() => _HRCollapsableNavbarState();
}

class _HRCollapsableNavbarState extends State<HRCollapsableNavbar>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          boxShadow: [
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildEnhancedSidebarHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                cacheExtent: 200,
                children: [
                  _buildAnimatedNavItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    index: 0,
                  ),
                  const SizedBox(height: 4),
                  _buildAnimatedNavItem(
                    icon: Icons.campaign_rounded,
                    title: 'Announcements',
                    index: 1,
                  ),
                  const SizedBox(height: 4),
                  _buildAnimatedNavItem(
                    icon: Icons.event_note_rounded,
                    title: 'Leave Requests',
                    index: 2,
                  ),
                  const SizedBox(height: 4),
                  _buildAnimatedNavItem(
                    icon: Icons.people_rounded,
                    title: 'Manage Employees',
                    index: 3,
                  ),
                  const SizedBox(height: 4),
                  _buildAnimatedNavItem(
                    icon: Icons.message_rounded,
                    title: 'Message',
                    index: 4,
                  ),
                  const SizedBox(height: 4),
                  _buildAnimatedNavItem(
                    icon: Icons.account_circle_rounded,
                    title: 'Profile',
                    index: 5,
                  ),
                ],
              ),
            ),
            _buildEnhancedLogoutTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSidebarHeader() {
    final displayName = widget.hrProfile?.name ?? widget.userName;
    final hasProfileImage =
        widget.hrProfile?.profilePicture != null &&
        widget.hrProfile!.profilePicture.isNotEmpty;

    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 240,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasProfileImage
                    ? Image.network(
                        '${ApiConstants.baseUrl}${widget.hrProfile!.profilePicture}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.edgePrimary,
                            child: _buildDefaultHeaderAvatar(displayName),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.edgePrimary,
                        child: _buildDefaultHeaderAvatar(displayName),
                      ),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned.fill(
                child: FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: SlideTransition(
                    position: _headerSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultHeaderAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'H',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: [
            Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedNavItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = widget.selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.edgePrimary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? AppColors.edgePrimary.withOpacity(0.2)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onItemSelected(index);
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.edgePrimary.withOpacity(0.1),
          highlightColor: AppColors.edgePrimary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.edgePrimary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppColors.edgePrimary
                        : AppColors.edgeTextSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.edgePrimary
                          : AppColors.edgeText,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgePrimary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedLogoutTile() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.edgeError, AppColors.edgeError.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeError.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onLogout,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/announcement_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/data/models/announcement_model.dart';
import '../../common/announcement_preview_dialog.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_loading_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_error_state.dart';
import 'package:hrm_app/presentation/widgets/common/states/custom_empty_state.dart';

class RecentActivityWidget extends StatefulWidget {
  const RecentActivityWidget({super.key});

  @override
  State<RecentActivityWidget> createState() => _RecentActivityWidgetState();
}

class _RecentActivityWidgetState extends State<RecentActivityWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final announcementProvider = Provider.of<AnnouncementProvider>(
        context,
        listen: false,
      );

      announcementProvider.loadAnnouncements(authProvider.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallDevice ? 18 : 22),
        child: _buildAnnouncementsSection(isSmallDevice),
      ),
    );
  }

  Widget _buildAnnouncementsSection(bool isSmallDevice) {
    return Consumer<AnnouncementProvider>(
      builder: (context, announcementProvider, child) {
        if (announcementProvider.isLoading) {
          return CustomLoadingState(
            message: 'Loading announcements...',
            isSmallDevice: isSmallDevice,
          );
        }

        if (announcementProvider.error != null) {
          return CustomErrorState(
            message: 'Failed to load announcements',
            isSmallDevice: isSmallDevice,
          );
        }

        final recentAnnouncements = announcementProvider.announcements;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnhancedHeader(isSmallDevice, recentAnnouncements.length),
            const SizedBox(height: 16),
            if (recentAnnouncements.isEmpty)
              CustomEmptyState(
                title: 'No recent announcements',
                subtitle: 'Announcements will appear here when created',
                icon: Icons.campaign_outlined,
                isSmallDevice: isSmallDevice,
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: recentAnnouncements
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildAnimatedAnnouncementItem(
                            entry.value,
                            entry.key,
                            isSmallDevice,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedHeader(bool isSmallDevice, int announcementCount) {
    return Row(
      children: [
        Container(
          width: isSmallDevice ? 36 : 40,
          height: isSmallDevice ? 36 : 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.edgePrimary.withOpacity(0.15),
                AppColors.edgePrimary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.edgePrimary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.edgePrimary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.campaign_rounded,
            color: AppColors.edgePrimary,
            size: isSmallDevice ? 18 : 20,
          ),
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Announcements',
                style: TextStyle(
                  fontSize: isSmallDevice ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Latest updates and news',
                style: TextStyle(
                  fontSize: isSmallDevice ? 12 : 13,
                  color: AppColors.edgeTextSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),

        if (announcementCount > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallDevice ? 10 : 12,
              vertical: isSmallDevice ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.edgePrimary.withOpacity(0.1),
                  AppColors.edgePrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.edgePrimary.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 8, color: AppColors.edgePrimary),
                const SizedBox(width: 6),
                Text(
                  '$announcementCount',
                  style: TextStyle(
                    fontSize: isSmallDevice ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.edgePrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAnimatedAnnouncementItem(
    AnnouncementModel announcement,
    int index,
    bool isSmallDevice,
  ) {
    return _buildEnhancedAnnouncementItem(announcement, isSmallDevice);
  }

  Widget _buildEnhancedAnnouncementItem(
    AnnouncementModel announcement,
    bool isSmallDevice,
  ) {
    return GestureDetector(
      onTap: () {
        _triggerHaptic();
        _showAnnouncementPreview(announcement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isSmallDevice ? 16 : 18),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.edgeDivider.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: TextStyle(
                      fontSize: isSmallDevice ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.edgeText,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallDevice ? 8 : 10,
                    vertical: isSmallDevice ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPriorityColor(
                          announcement.priority,
                        ).withOpacity(0.1),
                        _getPriorityColor(
                          announcement.priority,
                        ).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getPriorityColor(
                        announcement.priority,
                      ).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getPriorityColor(
                          announcement.priority,
                        ).withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    announcement.priorityDisplayName,
                    style: TextStyle(
                      fontSize: isSmallDevice ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(announcement.priority),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              announcement.message,
              style: TextStyle(
                fontSize: isSmallDevice ? 12 : 13,
                color: AppColors.edgeTextSecondary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.edgeTextSecondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.edgeTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        announcement.createdByName.isNotEmpty
                            ? announcement.createdByName
                            : 'Unknown',
                        style: TextStyle(
                          fontSize: isSmallDevice ? 10 : 11,
                          color: AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.edgePrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        announcement.timeAgo,
                        style: TextStyle(
                          fontSize: isSmallDevice ? 10 : 11,
                          color: AppColors.edgePrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppColors.edgeError;
      case 'high':
        return AppColors.edgeWarning;
      case 'normal':
        return AppColors.edgePrimary;
      case 'low':
        return AppColors.edgeTextSecondary;
      default:
        return AppColors.edgePrimary;
    }
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _showAnnouncementPreview(AnnouncementModel announcement) {
    final announcementData = {
      'title': announcement.title,
      'message': announcement.message,
      'priority': announcement.priority,
      'audience': announcement.audience,
      'createdBy': {
        'fullName': announcement.createdByName.isNotEmpty
            ? announcement.createdByName
            : 'Unknown',
      },
      'createdAt': announcement.createdAt,
      'announcementId': announcement.id,
    };

    showAnnouncementPreview(context, announcementData);
  }
}

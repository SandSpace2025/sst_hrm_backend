import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/announcement_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class RecentAnnouncementsList extends StatelessWidget {
  final List<AnnouncementModel> announcements;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final bool hasMoreData;
  final VoidCallback? onLoadMore;
  final bool showOnlyRecent;

  const RecentAnnouncementsList({
    super.key,
    required this.announcements,
    this.onRefresh,
    this.isLoading = false,
    this.hasMoreData = false,
    this.onLoadMore,
    this.showOnlyRecent = false,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;
    final filteredAnnouncements = showOnlyRecent
        ? announcements.where((a) => a.isRecent).toList()
        : announcements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onRefresh != null) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallDevice ? 12 : 16,
              vertical: isSmallDevice ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.edgePrimary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Announcements',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: () {
                      _triggerHaptic();
                      onRefresh!();
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.edgePrimary,
                    ),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (filteredAnnouncements.isEmpty && !isLoading)
          _buildEmptyState()
        else
          ...filteredAnnouncements.map((announcement) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: AnnouncementListItem(
                announcement: announcement,
                isSmallDevice: isSmallDevice,
              ),
            );
          }),
        if (isLoading && filteredAnnouncements.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.edgePrimary,
                    strokeWidth: 2.5,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Loading more...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (hasMoreData && !isLoading && onLoadMore != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  _triggerHaptic();
                  onLoadMore!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.edgePrimary,
                  foregroundColor: AppColors.edgeSurface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.expand_more_rounded, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Load More',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              size: 32,
              color: AppColors.edgePrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No announcements yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first announcement to get started',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.edgeTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AnnouncementListItem extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isSmallDevice;

  const AnnouncementListItem({
    super.key,
    required this.announcement,
    required this.isSmallDevice,
  });

  static const edgePrimary = Color(0xFF0F6CBD);
  static const edgeAccent = Color(0xFF107C10);
  static const edgeWarning = Color(0xFFF7630C);
  static const edgeError = Color(0xFFD13438);
  static const edgeSurface = Color(0xFFFFFFFF);
  static const edgeText = Color(0xFF323130);
  static const edgeTextSecondary = Color(0xFF605E5C);
  static const edgeDivider = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    Color priorityColor = edgeAccent;
    if (announcement.priority == 'high') priorityColor = edgeWarning;
    if (announcement.priority == 'urgent') priorityColor = edgeError;

    IconData audienceIcon = Icons.groups_rounded;
    if (announcement.audience == 'hr') {
      audienceIcon = Icons.manage_accounts_rounded;
    }
    if (announcement.audience == 'employees') {
      audienceIcon = Icons.person_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edgeDivider, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallDevice ? 16 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: TextStyle(
                                fontSize: isSmallDevice ? 15 : 16,
                                fontWeight: FontWeight.w600,
                                color: edgeText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: edgePrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              audienceIcon,
                              size: 14,
                              color: edgePrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        announcement.message,
                        style: TextStyle(
                          fontSize: isSmallDevice ? 13 : 14,
                          color: edgeTextSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: edgeTextSecondary.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            announcement.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: edgeTextSecondary.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: priorityColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              announcement.priorityDisplayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ],
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
}

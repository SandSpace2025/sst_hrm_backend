import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../common/announcement_preview_dialog.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class RecentAnnouncements extends StatefulWidget {
  final Map<String, dynamic>? dashboardData;

  const RecentAnnouncements({super.key, required this.dashboardData});

  @override
  State<RecentAnnouncements> createState() => _RecentAnnouncementsState();
}

class _RecentAnnouncementsState extends State<RecentAnnouncements>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    if (widget.dashboardData == null) {
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
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.edgePrimary),
          ),
        ),
      );
    }

    var announcements =
        widget.dashboardData!['recentAnnouncements'] as List<dynamic>? ?? [];

    announcements = announcements.where((item) {
      if (item is! Map) return false;
      final timestamp = item['createdAt'] ?? item['timestamp'];
      if (timestamp == null) return false;
      try {
        final date = DateTime.parse(timestamp.toString());
        final diff = DateTime.now().difference(date);
        return diff.inDays <= 5; // Match backend logic (5 days)
      } catch (_) {
        return false;
      }
    }).toList();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnhancedHeader(isSmallDevice, announcements.length),
            const SizedBox(height: 16),
            if (announcements.isEmpty)
              _buildEmptyState(isSmallDevice)
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: announcements
                        .asMap()
                        .entries
                        .map(
                          (entry) => _buildEnhancedAnnouncementItem(
                            entry.value,
                            isSmallDevice,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
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

  Widget _buildEmptyState(bool isSmallDevice) {
    return Container(
      padding: EdgeInsets.all(isSmallDevice ? 24 : 28),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: isSmallDevice ? 48 : 56,
            height: isSmallDevice ? 48 : 56,
            decoration: BoxDecoration(
              color: AppColors.edgeTextSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: isSmallDevice ? 24 : 28,
              color: AppColors.edgeTextSecondary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent announcements',
            style: TextStyle(
              fontSize: isSmallDevice ? 14 : 15,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Announcements will appear here when created',
            style: TextStyle(
              fontSize: isSmallDevice ? 12 : 13,
              color: AppColors.edgeTextSecondary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAnnouncementItem(
    dynamic announcement,
    bool isSmallDevice,
  ) {
    if (announcement is! Map) {
      return const SizedBox.shrink();
    }

    // safe access without strict casting
    final announcementMap = announcement;

    final title = announcementMap['title'] ?? 'Announcement';
    final content =
        announcementMap['message'] ?? announcementMap['content'] ?? '';

    String author = 'Unknown';
    final createdByRaw = announcementMap['createdBy'];
    if (createdByRaw != null) {
      if (createdByRaw is Map) {
        author = createdByRaw['fullName'] ?? createdByRaw['name'] ?? 'Unknown';
      } else if (createdByRaw is String) {
        // Some legacy data might have ID as string? keeping strictly unknown if not map/string name
        // or if it was just a name string:
        // author = createdByRaw;
        // Assuming it's usually an object.
      }
    }

    final timestamp =
        announcementMap['createdAt'] ?? announcementMap['timestamp'] ?? '';
    final priority = announcementMap['priority'] ?? 'normal';

    return GestureDetector(
      onTap: () {
        _triggerHaptic();
        try {
          _showAnnouncementPreview(Map<String, dynamic>.from(announcementMap));
        } catch (_) {}
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
                    title,
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
                        _getPriorityColor(priority).withOpacity(0.1),
                        _getPriorityColor(priority).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getPriorityColor(priority).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getPriorityColor(priority).withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: isSmallDevice ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(priority),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
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
                        author,
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
                        _formatTimestamp(timestamp),
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

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _showAnnouncementPreview(Map<String, dynamic> announcement) {
    showAnnouncementPreview(context, announcement);
  }
}

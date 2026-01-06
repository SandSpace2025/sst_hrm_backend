import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AnnouncementPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback? onClose;

  const AnnouncementPreviewDialog({
    super.key,
    required this.announcement,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Determine title and content
    final title = announcement['title'] ?? 'Announcement';
    final content = announcement['message'] ?? announcement['content'] ?? '';
    final createdAt = announcement['createdAt'] ?? announcement['timestamp'];
    final priority = announcement['priority'] ?? 'normal';
    final author = _getAuthorName();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Decoration (Top Right Circle)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9), // Very light green
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Megaphone Icon
          Positioned(
            top: 60,
            right: -20,
            child: Transform.rotate(
              angle: -0.4,
              child: Icon(
                Icons.campaign_rounded,
                size: 180,
                color: AppColors.success.withOpacity(0.3),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GestureDetector(
                    onTap: onClose ?? () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "Back",
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Priority Pill
                        if (priority != null && priority.toString().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(
                                priority,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: _getPriorityColor(priority),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  priority.toString()[0].toUpperCase() +
                                      priority.toString().substring(1),
                                  style: TextStyle(
                                    color: _getPriorityColor(priority),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Main Heading
                        Text(
                          title, // Use title as the main subject heading
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sender Info
                        Text(
                          "Announcement from $author",
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Content Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4), // Very light green
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.success.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Inner Card Title
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Date Row
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: AppColors.textSecondary.withOpacity(
                                      0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(createdAt),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Description
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Mark as read",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(dynamic priority) {
    switch (priority.toString().toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.textSecondary;
      default:
        return AppColors.success;
    }
  }

  String _getAuthorName() {
    if (announcement['createdBy'] != null) {
      if (announcement['createdBy'] is Map<String, dynamic>) {
        final createdBy = announcement['createdBy'] as Map<String, dynamic>;
        return createdBy['fullName'] ?? createdBy['name'] ?? 'Hr & Admin';
      } else if (announcement['createdBy'] is String) {
        return announcement['createdBy'];
      }
    }
    return 'Hr & Admin';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else {
        date = DateTime.parse(timestamp.toString());
      }
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return '';
    }
  }
}

void showAnnouncementPreview(
  BuildContext context,
  Map<String, dynamic> announcement, {
  VoidCallback? onClose,
}) {
  if (!context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: true,
    useSafeArea: false,
    builder: (BuildContext context) {
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: AnnouncementPreviewDialog(
          announcement: announcement,
          onClose: onClose,
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class NotificationsSection extends StatelessWidget {
  final Map<String, dynamic>? dashboardData;

  const NotificationsSection({super.key, required this.dashboardData});

  @override
  Widget build(BuildContext context) {
    if (dashboardData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.edgeDivider),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.edgePrimary),
        ),
      );
    }

    final notifications =
        dashboardData!['notifications'] as List<dynamic>? ?? [];
    final messages = dashboardData!['recentMessages'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.edgeDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: AppColors.edgePrimary,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty && messages.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.edgeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.edgeAccent.withOpacity(0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.edgeAccent,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No new notifications',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.edgeText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...notifications.map(
              (notification) =>
                  _buildNotificationCard(notification: notification),
            ),
            ...messages.map(
              (message) => _buildMessageNotificationCard(message),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard({required Map<String, dynamic> notification}) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'info';
    final timestamp = notification['timestamp'] ?? '';

    Color typeColor;
    IconData typeIcon;

    switch (type.toLowerCase()) {
      case 'success':
        typeColor = AppColors.edgeAccent;
        typeIcon = Icons.check_circle_outline;
        break;
      case 'warning':
        typeColor = AppColors.edgeWarning;
        typeIcon = Icons.warning_outlined;
        break;
      case 'error':
        typeColor = AppColors.edgeError;
        typeIcon = Icons.error_outline;
        break;
      default:
        typeColor = AppColors.edgePrimary;
        typeIcon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 14, color: typeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
              ),
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.edgeTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.edgeTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageNotificationCard(Map<String, dynamic> message) {
    final senderName = message['senderName'] ?? 'Unknown';
    final content = message['content'] ?? '';
    final timestamp = message['timestamp'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.edgePrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.edgePrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.message_outlined,
                size: 14,
                color: AppColors.edgePrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'New message from $senderName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
              ),
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.edgeTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.edgeTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
}

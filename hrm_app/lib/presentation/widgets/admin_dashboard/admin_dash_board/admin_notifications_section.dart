import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AdminNotificationsSection extends StatelessWidget {
  final Map<String, dynamic>? dashboardData;
  final Function(int) onNavigateToIndex;
  final Function(Map<String, dynamic>) onMessageTap;
  final Function(String) onMarkMessageAsRead;

  const AdminNotificationsSection({
    super.key,
    required this.dashboardData,
    required this.onNavigateToIndex,
    required this.onMessageTap,
    required this.onMarkMessageAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final unreadMessages = dashboardData?['unreadMessages'] ?? 0;
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
        Row(
          children: [
            Expanded(
              child: _buildNotificationSummaryCard(
                title: 'Unread Messages',
                count: unreadMessages,
                icon: Icons.message_outlined,
                color: AppColors.edgeError,
                onTap: () => onNavigateToIndex(4), // Index 4 = Messaging
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNotificationSummaryCard(
                title: 'Pending Leaves',
                count: pendingLeaves,
                icon: Icons.event_note_outlined,
                color: AppColors.edgeWarning,
                onTap: () => onNavigateToIndex(3), // Index 3 = Leave Requests
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
          if (unreadMessages > 0) ...[
            ...unreadMessagesData
                .take(3)
                .map<Widget>(
                  (message) => _buildMessageNotificationCard(message),
                )
                .toList(),
          ],
          if (unreadMessages > 0 && pendingLeaves > 0)
            const SizedBox(height: 12),
          if (pendingLeaves > 0) ...[
            ...pendingLeavesData
                .take(3)
                .map<Widget>(
                  (leaveRequest) =>
                      _buildLeaveRequestNotificationCard(leaveRequest),
                )
                .toList(),
          ],
        ] else ...[
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
          onTap: () => onMessageTap(message),
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
                  onPressed: () => onMarkMessageAsRead(messageId),
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

  Widget _buildLeaveRequestNotificationCard(Map<String, dynamic> leaveRequest) {
    final employeeName = leaveRequest['employeeName'] ?? 'Unknown Employee';
    final leaveType = leaveRequest['leaveType'] ?? 'Leave';
    final startDate = leaveRequest['startDate'] ?? '';
    final endDate = leaveRequest['endDate'] ?? '';
    final reason = leaveRequest['reason'] ?? '';
    final isEmergency = leaveRequest['isEmergency'] ?? false;

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
          onTap: () => onNavigateToIndex(3), // Index 3 = Leave Requests
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

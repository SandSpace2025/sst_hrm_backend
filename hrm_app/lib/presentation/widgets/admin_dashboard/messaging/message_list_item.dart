import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/message_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class MessageListItem extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const MessageListItem({
    super.key,
    required this.message,
    this.onTap,
    this.onMarkAsRead,
    this.onArchive,
    this.onDelete,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: message.isRead
              ? AppColors.edgeDivider
              : AppColors.edgePrimary.withOpacity(0.5),
          width: message.isRead ? 1 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _triggerHaptic();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(message.priority),
                        borderRadius: BorderRadius.circular(2),
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
                                  message.subject,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: message.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    color: AppColors.edgeText,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!message.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.edgePrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message.content,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.edgeTextSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _triggerHaptic();
                        switch (value) {
                          case 'mark_read':
                            onMarkAsRead?.call();
                            break;
                          case 'archive':
                            onArchive?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      itemBuilder: (context) => [
                        if (!message.isRead)
                          const PopupMenuItem(
                            value: 'mark_read',
                            child: Row(
                              children: [
                                Icon(Icons.mark_email_read_outlined, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Mark as Read',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Archive', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: AppColors.edgeError,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: AppColors.edgeError,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      child: const Icon(
                        Icons.more_vert,
                        color: AppColors.edgeTextSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      message.isFromAdmin
                          ? Icons.send_outlined
                          : Icons.reply_outlined,
                      size: 14,
                      color: AppColors.edgeTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        message.isFromAdmin
                            ? 'To: ${message.receiverName}'
                            : 'From: ${message.senderName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.edgeTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (message.priority != 'normal') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(
                            message.priority,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          message.priorityDisplayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _getPriorityColor(message.priority),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.edgeTextSecondary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.edgeTextSecondary.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getMessageTypeColor(
                          message.messageType,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        message.messageTypeDisplayName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getMessageTypeColor(message.messageType),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      message.statusDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(message.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 14,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${message.attachments.length} attachment${message.attachments.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.edgeTextSecondary,
                          ),
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppColors.edgeError;
      case 'high':
        return AppColors.edgeWarning;
      case 'normal':
        return AppColors.edgePrimary;
      case 'low':
        return AppColors.edgeAccent;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  Color _getMessageTypeColor(String messageType) {
    switch (messageType.toLowerCase()) {
      case 'admin_to_employee':
        return AppColors.edgePrimary;
      case 'admin_to_hr':
        return AppColors.edgeSecondary;
      case 'hr_to_admin':
        return AppColors.edgeAccent;
      case 'employee_to_admin':
        return AppColors.edgeSecondary;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return AppColors.edgePrimary;
      case 'delivered':
        return AppColors.edgeAccent;
      case 'read':
        return AppColors.edgeSecondary;
      case 'archived':
        return AppColors.edgeTextSecondary;
      default:
        return AppColors.edgeTextSecondary;
    }
  }
}

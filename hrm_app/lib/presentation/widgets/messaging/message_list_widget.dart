import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import '../../../core/models/message.dart';

class MessageListWidget extends StatefulWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final VoidCallback? onLoadMore;
  final bool hasMoreMessages;
  final bool isLoadingMore;
  final String? currentUserId;

  const MessageListWidget({
    super.key,
    required this.messages,
    required this.scrollController,
    this.onLoadMore,
    this.hasMoreMessages = false,
    this.isLoadingMore = false,
    this.currentUserId,
  });

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      itemCount: widget.messages.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final message = widget.messages[index];
        return MessageBubble(
          message: message,
          isOwnMessage: _isOwnMessage(message),
        );
      },
    );
  }

  bool _isOwnMessage(Message message) {
    if (widget.currentUserId == null) return false;
    return message.sender.userId == widget.currentUserId;
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwnMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = AppColors.primary;
    final textColor = Colors.white;
    final timeColor = Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                message.sender.name.isNotEmpty
                    ? message.sender.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: CustomPaint(
              painter: ChatBubblePainter(
                color: bubbleColor,
                isOwnMessage: isOwnMessage,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isOwnMessage ? 12 : 20,
                  12,
                  isOwnMessage ? 20 : 12,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isOwnMessage)
                      Text(
                        message.sender.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    if (!isOwnMessage) const SizedBox(height: 4),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize:
                            15, // Increased slightly for better readability
                        fontWeight: FontWeight.w500, // Increased weight
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(fontSize: 10, color: timeColor),
                        ),
                        if (isOwnMessage) ...[
                          const SizedBox(width: 4),
                          Icon(
                            _getStatusIcon(message.status),
                            size: 12,
                            color: timeColor,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwnMessage) ...[const SizedBox(width: 8)],
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      default:
        return Icons.schedule;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ChatBubblePainter extends CustomPainter {
  final Color color;
  final bool isOwnMessage;

  ChatBubblePainter({required this.color, required this.isOwnMessage});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;

    if (!isOwnMessage) {
      // Received Message (Left) -> Sharp Bottom Left
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, w, h),
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomRight: const Radius.circular(12),
          bottomLeft: Radius.zero,
        ),
        paint,
      );

      Path tail = Path();
      tail.moveTo(0, h);
      tail.lineTo(-8, h);
      tail.lineTo(0, h - 10);
      tail.close();
      canvas.drawPath(tail, paint);
    } else {
      // Sent Message (Right) -> Sharp Bottom Right
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, w, h),
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: const Radius.circular(12),
          bottomRight: Radius.zero,
        ),
        paint,
      );

      Path tail = Path();
      tail.moveTo(w, h);
      tail.lineTo(w + 8, h);
      tail.lineTo(w, h - 10);
      tail.close();
      canvas.drawPath(tail, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

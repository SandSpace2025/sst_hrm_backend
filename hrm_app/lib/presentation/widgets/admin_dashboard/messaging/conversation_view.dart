import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/data/models/message_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class ConversationView extends StatefulWidget {
  final String userId;
  final String userType;
  final VoidCallback onClose;

  const ConversationView({
    super.key,
    required this.userId,
    required this.userType,
    required this.onClose,
  });

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView>
    with SingleTickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 400);
  static const Curve _animCurve = Curves.easeOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _priority = 'normal';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _animDuration);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: _animCurve));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversation();
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  void _loadConversation() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final messageProvider = Provider.of<MessageProvider>(
        context,
        listen: false,
      );
      messageProvider.loadConversation(
        widget.userId,
        widget.userType,
        authProvider.token!,
        refresh: true,
      );
    }
  }

  Future<void> _sendMessage() async {
    _triggerHaptic();

    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );
    bool success = false;

    final userTypeLower = widget.userType.toLowerCase();

    if (userTypeLower == 'employee' || userTypeLower == 'hr') {
      success = await messageProvider.sendMessageToEmployee(
        widget.userId,
        'Re: Conversation',
        _messageController.text.trim(),
        authProvider.token!,
        priority: _priority,
      );
    } else if (userTypeLower == 'admin') {
      success = await messageProvider.sendMessageToHR(
        widget.userId,
        'Re: Conversation',
        _messageController.text.trim(),
        authProvider.token!,
        priority: _priority,
      );
    } else {
      success = await messageProvider.sendMessageToEmployee(
        widget.userId,
        'Re: Conversation',
        _messageController.text.trim(),
        authProvider.token!,
        priority: _priority,
      );
    }

    if (success) {
      _messageController.clear();
      _loadConversation();
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageProvider.error ?? 'Failed to send message'),
            backgroundColor: AppColors.edgeError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: _animDuration,
          curve: _animCurve,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.edgeDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _triggerHaptic();
              widget.onClose();
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: AppColors.edgeTextSecondary,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.userType.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.edgePrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'ID: ${widget.userId.substring(0, 8)}...',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.edgeTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              _triggerHaptic();
              setState(() {
                _priority = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'low', child: Text('Low Priority')),
              const PopupMenuItem(value: 'normal', child: Text('Normal')),
              const PopupMenuItem(value: 'high', child: Text('High Priority')),
              const PopupMenuItem(value: 'urgent', child: Text('Urgent')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(_priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getPriorityColor(_priority).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getPriorityIcon(_priority),
                    size: 12,
                    color: _getPriorityColor(_priority),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getPriorityColor(_priority),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Consumer<MessageProvider>(
      builder: (context, messageProvider, child) {
        if (messageProvider.isLoading &&
            messageProvider.conversationMessages.isEmpty) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.edgePrimary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (messageProvider.conversationMessages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.edgeTextSecondary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: AppColors.edgeTextSecondary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start the conversation below',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeTextSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: messageProvider.conversationMessages.length,
          itemBuilder: (context, index) {
            final message = messageProvider.conversationMessages[index];
            return TweenAnimationBuilder<double>(
              duration: _animDuration,
              curve: _animCurve,
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
              child: _buildMessageBubble(message),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(top: BorderSide(color: AppColors.edgeDivider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(fontSize: 13, color: AppColors.edgeText),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.edgeTextSecondary.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.edgeDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.edgeDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.edgePrimary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.edgePrimary,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.send,
                  color: AppColors.edgeSurface,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isFromAdmin = message.isFromAdmin;
    final isRead = message.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromAdmin
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromAdmin) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.edgeSecondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  message.senderName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.edgeSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isFromAdmin
                    ? AppColors.edgePrimary
                    : AppColors.edgeDivider.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isFromAdmin
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isFromAdmin
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.subject != 'Re: Conversation') ...[
                    Text(
                      message.subject,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isFromAdmin
                            ? AppColors.edgeSurface
                            : AppColors.edgeText,
                        fontSize: 12,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isFromAdmin
                          ? AppColors.edgeSurface
                          : AppColors.edgeText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: isFromAdmin
                              ? AppColors.edgeSurface.withOpacity(0.7)
                              : AppColors.edgeTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isFromAdmin) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead
                              ? AppColors.edgeSurface
                              : AppColors.edgeSurface.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isFromAdmin) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.edgeAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppColors.edgeAccent,
                size: 14,
              ),
            ),
          ],
        ],
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

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Icons.priority_high;
      case 'high':
        return Icons.arrow_upward;
      case 'normal':
        return Icons.remove;
      case 'low':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }
}

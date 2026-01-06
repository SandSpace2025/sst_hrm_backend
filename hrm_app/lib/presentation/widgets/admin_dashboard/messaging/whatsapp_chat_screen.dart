import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:hrm_app/presentation/providers/message_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/data/models/message_model.dart' as models;
import 'package:hrm_app/core/services/websocket_service.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class WhatsAppChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userType;

  const WhatsAppChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userType,
  });

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen>
    with TickerProviderStateMixin {
  static const Duration _animDuration = Duration(milliseconds: 300);
  static const Duration _fastAnimDuration = Duration(milliseconds: 200);
  static const Duration _slowAnimDuration = Duration(milliseconds: 500);
  static const Curve _animCurve = Curves.easeInOutCubic;
  static const Curve _bounceCurve = Curves.elasticOut;
  static const Curve _slideCurve = Curves.easeOutBack;

  late AnimationController _mainController;
  late AnimationController _messageAnimController;
  late AnimationController _typingController;
  late AnimationController _sendController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _typingAnimation;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _isSending = false;
  final bool _isPeerTyping = false;
  String? _myUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  List<models.MessageModel> _localMessages = [];

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(vsync: this, duration: _animDuration);
    _messageAnimController = AnimationController(
      vsync: this,
      duration: _fastAnimDuration,
    );
    _typingController = AnimationController(
      vsync: this,
      duration: _slowAnimDuration,
    );
    _sendController = AnimationController(
      vsync: this,
      duration: _fastAnimDuration,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: _animCurve));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainController, curve: _slideCurve));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _mainController, curve: _bounceCurve));

    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );

    try {
      Provider.of<AdminProvider>(
        context,
        listen: false,
      ).setCurrentChatPartner(widget.userId);
    } catch (e) {}

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversation();
      _setupMessageStreamSubscription();
      _extractMyUserId();

      try {
        Provider.of<AdminProvider>(
          context,
          listen: false,
        ).setCurrentChatPartner(widget.userId);
      } catch (e) {}

      _mainController.forward();
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<AdminProvider>(
        context,
        listen: false,
      ).setCurrentChatPartner(null);
    } catch (e) {}

    _messageSubscription?.cancel();
    _mainController.dispose();
    _messageAnimController.dispose();
    _typingController.dispose();
    _sendController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
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
      messageProvider
          .loadConversation(
            widget.userId,
            widget.userType,
            authProvider.token!,
            refresh: false,
            forceRefresh: false,
          )
          .then((_) {
            setState(() {
              _localMessages = List.from(messageProvider.conversationMessages);

              _localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });
          });
    }
  }

  void _extractMyUserId() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        final payload = Jwt.parseJwt(authProvider.token!);
        _myUserId = (payload['userId'] ?? payload['id'])?.toString();
      }
    } catch (e) {}
  }

  void _setupMessageStreamSubscription() {
    final webSocketService = WebSocketService();

    _messageSubscription = webSocketService.messageStream.listen(
      (data) {
        final messageData = data['data'] ?? data;
        final senderId = messageData['sender']?['_id']?.toString();

        final currentUserId = widget.userId;

        final isFromCurrentUser = senderId == currentUserId;

        final shouldProcessMessage = isFromCurrentUser;

        if (shouldProcessMessage) {
          try {
            final transformedData = _transformWebSocketData(messageData);
            final newMessage = models.MessageModel.fromJson(transformedData);

            final existingMessageIndex = _localMessages.indexWhere(
              (msg) => msg.id == newMessage.id,
            );

            setState(() {
              if (existingMessageIndex != -1) {
                _localMessages[existingMessageIndex] = newMessage;
              } else {
                _localMessages.add(newMessage);

                _messageAnimController.forward().then((_) {
                  _messageAnimController.reset();
                });
              }

              _localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          } catch (e) {}
        }
      },
      onError: (error) {},
      onDone: () {},
    );
  }

  Map<String, dynamic> _transformWebSocketData(Map<String, dynamic> data) {
    final messageType = data['messageType']?.toString() ?? '';

    String senderModel, receiverModel;
    if (messageType.startsWith('admin_to_')) {
      senderModel = 'Admin';
      receiverModel = messageType.contains('employee') ? 'Employee' : 'HR';
    } else if (messageType.startsWith('employee_to_')) {
      senderModel = 'Employee';
      receiverModel = messageType.contains('admin') ? 'Admin' : 'HR';
    } else if (messageType.startsWith('hr_to_')) {
      senderModel = 'HR';
      receiverModel = 'Employee';
    } else {
      senderModel = messageType.contains('admin') ? 'Admin' : 'Employee';
      receiverModel = messageType.contains('admin') ? 'Employee' : 'Admin';
    }

    return {
      '_id': data['messageId'] ?? '',
      'sender': data['sender'] ?? {},
      'receiver': data['receiver'] ?? {},
      'senderModel': senderModel,
      'receiverModel': receiverModel,
      'subject': data['subject'] ?? '',
      'content': data['content'] ?? '',
      'messageType': data['messageType'] ?? '',
      'priority': data['priority'] ?? 'normal',
      'status': 'sent',
      'isRead': false,
      'isArchived': false,
      'isReply': false,
      'attachments': [],
      'isScheduled': false,
      'deliveryAttempts': 0,
      'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    _triggerHaptic();

    final messageContent = _messageController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final payload = Jwt.parseJwt(authProvider.token!);
    final senderId = payload['userId'] ?? payload['id'] ?? '';

    final tempMessage = models.MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId.toString(),
      senderName: 'Admin',
      senderEmail: 'admin@admin.com',
      senderModel: 'Admin',
      receiverId: widget.userId,
      receiverName: widget.userName,
      receiverEmail: 'user@example.com',
      receiverModel: widget.userType == 'employee' ? 'Employee' : 'HR',
      subject: 'Chat Message',
      content: messageContent,
      messageType: 'admin_to_${widget.userType}',
      priority: 'normal',
      status: 'sending',
      isRead: false,
      isArchived: false,
      isReply: false,
      attachments: const [],
      isScheduled: false,
      deliveryAttempts: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _isSending = true;
      _localMessages.add(tempMessage);

      _localMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });

    _sendController.forward().then((_) {
      _sendController.reset();
    });

    _messageController.clear();
    setState(() {});
    _scrollToBottom();

    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    final success = await messageProvider.sendMessage(
      receiverId: widget.userId,
      receiverType: widget.userType,
      subject: 'Chat Message',
      content: messageContent,
      token: authProvider.token!,
      attachments: null,
    );

    setState(() => _isSending = false);

    if (!success) {
      setState(() {
        _localMessages.removeWhere((msg) => msg.id == tempMessage.id);
      });
      _showErrorSnackbar('Failed to send message');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_rounded),
                title: const Text('Image'),
                onTap: () {
                  Navigator.pop(context);
                  _showErrorSnackbar('Image attachments will be enabled next.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text('PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _showErrorSnackbar('PDF attachments will be enabled next.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Expanded(
                    key: ValueKey('messages_${_localMessages.length}'),
                    child: _buildMessagesList(),
                  ),
                  AnimatedContainer(
                    duration: _fastAnimDuration,
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: keyboardHeight),
                    child: _buildMessageInput(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final wsConnected = Provider.of<WebSocketProvider>(context).isConnected;
    final statusText = _isPeerTyping
        ? 'typing…'
        : (wsConnected ? 'Online' : 'Offline');
    final statusColor = _isPeerTyping
        ? Colors.lightGreenAccent
        : (wsConnected ? Colors.white70 : Colors.white54);

    return AppBar(
      backgroundColor: AppColors.edgePrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          _triggerHaptic();
          Navigator.pop(context);
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Text(
              widget.userName.isNotEmpty
                  ? widget.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.userType.toLowerCase() == 'employee'
                          ? 'Employee'
                          : 'HR',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    final messageProvider = Provider.of<MessageProvider>(
      context,
      listen: false,
    );

    if (messageProvider.isLoading && _localMessages.isEmpty) {
      return _buildLoadingState();
    }

    if (messageProvider.error != null && _localMessages.isEmpty) {
      return _buildErrorState(messageProvider.error!);
    }

    if (_localMessages.isEmpty) {
      return _buildEmptyState();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        reverse: false,
        itemCount: _localMessages.length,
        itemBuilder: (context, index) {
          final message = _localMessages[index];
          final isFromAdmin =
              _myUserId != null && message.senderId == _myUserId;
          final showDateHeader = _shouldShowDateHeader(index, _localMessages);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDateHeader)
                _buildDateHeader(message.createdAt.toIso8601String()),
              _buildMessageBubble(message, isFromAdmin),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowDateHeader(int index, List<models.MessageModel> messages) {
    if (index == 0) return true;

    final currentDate = messages[index].createdAt;
    final previousDate = messages[index - 1].createdAt;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  Widget _buildDateHeader(String dateString) {
    final date = DateTime.parse(dateString);

    final istDate = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(istDate.year, istDate.month, istDate.day);

    String displayText;
    if (messageDate == today) {
      displayText = 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      displayText = 'Yesterday';
    } else {
      displayText = DateFormat('MMM dd, yyyy').format(istDate);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.edgeDivider.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.edgeTextSecondary,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(models.MessageModel message, bool isFromAdmin) {
    final istTime = message.createdAt.toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final time = DateFormat('hh:mm a').format(istTime);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTempMessage = message.id.startsWith('temp_');

    return AnimatedBuilder(
      animation: _messageAnimController,
      builder: (context, child) {
        return Transform.scale(
          scale: isTempMessage
              ? 0.95 + (0.05 * _messageAnimController.value)
              : 1.0,
          child: Transform.translate(
            offset: isTempMessage
                ? Offset(0, 10 * (1 - _messageAnimController.value))
                : Offset.zero,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: isFromAdmin
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
                    child: Container(
                      margin: EdgeInsets.only(
                        left: isFromAdmin ? 50 : 8,
                        right: isFromAdmin ? 8 : 50,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isFromAdmin
                            ? const Color(0xFF005C4B)
                            : AppColors.edgeSurface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(8),
                          topRight: const Radius.circular(8),
                          bottomLeft: Radius.circular(isFromAdmin ? 8 : 2),
                          bottomRight: Radius.circular(isFromAdmin ? 2 : 8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.subject != 'Chat Message' &&
                              message.subject.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                message.subject,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFromAdmin
                                      ? Colors.white.withOpacity(0.9)
                                      : AppColors.edgePrimary,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          if (message.content.isNotEmpty)
                            Text(
                              message.content,
                              style: TextStyle(
                                fontSize: 14,
                                color: isFromAdmin
                                    ? Colors.white
                                    : AppColors.edgeText,
                                height: 1.3,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isFromAdmin
                                      ? Colors.white.withOpacity(0.7)
                                      : AppColors.edgeTextSecondary,
                                ),
                              ),
                              if (isFromAdmin) ...[
                                const SizedBox(width: 4),
                                _buildReadReceipt(message),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadReceipt(models.MessageModel message) {
    final isRead = message.isRead;

    if (isRead) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(Icons.done_all, size: 16, color: Colors.blue)],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.white.withOpacity(0.7)),
        ],
      );
    }
  }

  Widget _buildMessageInput() {
    return AnimatedBuilder(
      animation: _sendController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (0.05 * _sendController.value),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              border: const Border(
                top: BorderSide(color: AppColors.edgeDivider, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.edgeTextSecondary,
                      ),
                      onPressed: _showAttachmentOptions,
                      tooltip: 'Attach',
                    ),
                    Expanded(
                      child: AnimatedContainer(
                        duration: _fastAnimDuration,
                        curve: _animCurve,
                        constraints: const BoxConstraints(
                          maxHeight: 100,
                          minHeight: 40,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.edgeBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _messageFocusNode.hasFocus
                                ? AppColors.edgePrimary.withOpacity(0.5)
                                : AppColors.edgeDivider,
                            width: _messageFocusNode.hasFocus ? 2 : 1,
                          ),
                          boxShadow: _messageFocusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: AppColors.edgePrimary.withOpacity(
                                      0.1,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: AppColors.edgeTextSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.edgeText,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          onChanged: (value) {
                            if (value.isNotEmpty &&
                                !_typingController.isAnimating) {
                              _typingController.forward().then((_) {
                                _typingController.reverse();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    AnimatedBuilder(
                      animation: _sendController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.1 * _sendController.value),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.edgePrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.edgePrimary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed:
                                  (_isSending ||
                                      (_messageController.text.trim().isEmpty))
                                  ? null
                                  : _sendMessage,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      _messageController.text.trim().isEmpty
                                          ? Icons.mic
                                          : Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.edgePrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppColors.edgePrimary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading messages...',
                    style: TextStyle(
                      color: AppColors.edgeTextSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: AppColors.edgePrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Failed to load messages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _mainController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: TextButton(
                            onPressed: _loadConversation,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.edgePrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(
                                  color: AppColors.edgePrimary,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _typingController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (0.1 * _typingAnimation.value),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.edgePrimary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: AppColors.edgePrimary,
                            ),
                          ),
                        );
                      },
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
                      'Start the conversation by sending a message',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

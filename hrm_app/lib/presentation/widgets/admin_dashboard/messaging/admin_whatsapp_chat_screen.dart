import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:hrm_app/presentation/providers/admin_provider.dart';
import 'package:hrm_app/presentation/providers/auth_provider.dart';
import 'package:hrm_app/core/services/websocket_service.dart';
import 'package:hrm_app/presentation/providers/websocket_provider.dart';
import 'package:intl/intl.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AdminWhatsAppChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userType;
  final bool fromNotification;

  const AdminWhatsAppChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userType,
    this.fromNotification = false,
  });

  @override
  State<AdminWhatsAppChatScreen> createState() =>
      _AdminWhatsAppChatScreenState();
}

class _AdminWhatsAppChatScreenState extends State<AdminWhatsAppChatScreen>
    with TickerProviderStateMixin {
  AdminProvider? _adminProvider;

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
  bool _isPeerTyping = false;
  bool _isOnline = false;
  String? _myUserId;
  String? _myJwtUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  DateTime? _lastSoftReloadAt;
  StreamSubscription<Map<String, dynamic>>? _presenceSubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;

  List<dynamic> _localMessages = [];

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

    _adminProvider = Provider.of<AdminProvider>(context, listen: false);
    _adminProvider!.setCurrentChatPartner(widget.userId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureWebSocketConnected();
      _extractMyUserId();

      _loadConversation(forceRefresh: widget.fromNotification);
      _setupMessageStreamSubscription();
      _setupPresenceSubscription();
      _setupTypingSubscription();

      if (_adminProvider != null) {
        _adminProvider!.setCurrentChatPartner(widget.userId);
      }

      try {
        final wsProvider = Provider.of<WebSocketProvider>(
          context,
          listen: false,
        );
        _isOnline = wsProvider.isOnlineId(widget.userId);
      } catch (_) {}
      _mainController.forward();
    });
  }

  @override
  void dispose() {
    _adminProvider?.setCurrentChatPartner(null);

    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingSubscription?.cancel();
    _mainController.dispose();
    _messageAnimController.dispose();
    _typingController.dispose();
    _sendController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  Future<void> _ensureWebSocketConnected() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token == null) return;
      final payload = Jwt.parseJwt(authProvider.token!);
      final myId = (payload['userId'] ?? payload['id'])?.toString();
      final myRole = (authProvider.role ?? 'admin').toString();
      if (myId == null) return;
      final ws = WebSocketService();
      if (!ws.isConnected) {
        await ws.connect(authProvider.token!, myId, myRole);
      }
    } catch (_) {}
  }

  void _extractMyUserId() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);

      if (authProvider.token != null) {
        try {
          final payload = Jwt.parseJwt(authProvider.token!);
          _myJwtUserId =
              (payload['userId'] ?? payload['id'] ?? payload['profileId'])
                  ?.toString();
        } catch (e) {}

        await adminProvider.loadAdminProfile(
          authProvider.token!,
          forceRefresh: false,
        );

        if (adminProvider.adminProfile != null) {
          _myUserId = adminProvider.adminProfile!.id;
        } else {
          _myUserId = _myJwtUserId;
        }
      }
    } catch (e) {}
  }

  Future<void> _loadConversation({bool forceRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      try {
        if (forceRefresh) {
          final connectivity = await Connectivity().checkConnectivity();
          final isOnline =
              connectivity.isNotEmpty &&
              connectivity.any((result) => result != ConnectivityResult.none);

          if (!isOnline) {
            if (!widget.fromNotification && mounted) {
              SnackBarUtils.showError(context, 'No internet connection');
            }
            return;
          }

          if (!widget.fromNotification && mounted) {
            SnackBarUtils.showInfo(context, 'Refreshing messages...');
          }
        }

        await adminProvider.getConversation(
          widget.userId,
          widget.userType,
          authProvider.token!,
          forceRefresh: forceRefresh || widget.fromNotification,
        );

        // Mark conversation as seen
        debugPrint(
          'AdminChatScreen: Calling markConversationAsSeen for ${widget.userId}',
        );
        await adminProvider.markConversationAsSeen(
          widget.userId,
          widget.userType,
          authProvider.token!,
        );

        if (mounted) {
          setState(() {
            if (adminProvider.messages.isNotEmpty) {
              final messageMap = <String, dynamic>{};

              for (final msg in _localMessages) {
                if (msg == null) continue;
                final msgId = msg['_id']?.toString() ?? '';
                if (msgId.isNotEmpty && !msgId.startsWith('temp_')) {
                  messageMap[msgId] = msg;
                }
              }

              for (final message in adminProvider.messages) {
                if (message == null) continue;
                final messageId = message['_id']?.toString() ?? '';
                if (messageId.isNotEmpty) {
                  messageMap[messageId] = message;
                }
              }

              _localMessages = messageMap.values.toList();
            } else {
              final filteredMessages = <dynamic>[];
              for (final msg in _localMessages) {
                if (msg == null) continue;
                final msgId = msg['_id']?.toString() ?? '';
                if (msgId.isNotEmpty && !msgId.startsWith('temp_')) {
                  filteredMessages.add(msg);
                }
              }
              _localMessages = filteredMessages;
            }

            _localMessages.sort((a, b) {
              if (a == null || b == null) return 0;
              final timeA =
                  DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                  DateTime.now();
              final timeB =
                  DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                  DateTime.now();
              return timeA.compareTo(timeB);
            });
          });
        }
      } catch (e) {}
    }
  }

  void _setupMessageStreamSubscription() {
    final webSocketService = WebSocketService();

    _messageSubscription = webSocketService.messageStream.listen(
      (data) {
        final raw = data['data'] ?? data;
        Map<String, dynamic> payload = Map<String, dynamic>.from(
          (raw is Map<String, dynamic>) ? raw : {},
        );
        if (payload.containsKey('message') && payload['message'] is Map) {
          payload = Map<String, dynamic>.from(payload['message'] as Map);
        }

        try {
          String? senderId;
          if (payload['sender'] is Map) {
            final s = payload['sender'] as Map;
            senderId = (s['_id'] ?? s['id'] ?? s['userId'])?.toString();
          } else {
            senderId = payload['sender']?.toString();
          }
          String? receiverId;
          if (payload['receiver'] is Map) {
            final r = payload['receiver'] as Map;
            receiverId = (r['_id'] ?? r['id'] ?? r['userId'])?.toString();
          } else {
            receiverId = payload['receiver']?.toString();
          }

          final partnerId = widget.userId;

          final normalizedPartnerId = partnerId.trim();
          final normalizedSenderId = senderId?.trim() ?? '';
          final normalizedReceiverId = receiverId?.trim() ?? '';
          final normalizedMyUserId = _myUserId?.trim() ?? '';

          final involvesPartner =
              normalizedSenderId == normalizedPartnerId ||
              normalizedReceiverId == normalizedPartnerId;

          final involvesMe =
              normalizedMyUserId.isNotEmpty &&
              (normalizedSenderId == normalizedMyUserId ||
                  normalizedReceiverId == normalizedMyUserId);

          if (!involvesPartner || !involvesMe) {
            _debouncedSoftReload();
            return;
          }

          final newMessage = _transformWebSocketData(payload);

          if ((newMessage['_id'] ?? '').toString().isEmpty) {
            return;
          }

          if (!mounted) return;

          final messageId = newMessage['_id']?.toString() ?? '';
          if (messageId.isEmpty) {
            return;
          }

          int tempMessageIndex = -1;

          final normalizedJwtUserId = _myJwtUserId?.trim() ?? '';
          final isMyMessage =
              normalizedSenderId.isNotEmpty &&
              ((normalizedMyUserId.isNotEmpty &&
                      normalizedSenderId == normalizedMyUserId) ||
                  (normalizedJwtUserId.isNotEmpty &&
                      normalizedSenderId == normalizedJwtUserId));

          final content = newMessage['content']?.toString() ?? '';
          if (content.isNotEmpty && isMyMessage) {
            tempMessageIndex = _localMessages.indexWhere((msg) {
              if (msg == null) return false;
              final msgId = msg['_id']?.toString() ?? '';
              final isTemp = msgId.startsWith('temp_');
              if (!isTemp) return false;

              final msgContent = msg['content']?.toString() ?? '';
              if (msgContent != content || content.isEmpty) return false;

              String? msgSenderId;
              if (msg['sender'] is Map) {
                final senderMap = msg['sender'] as Map;
                msgSenderId =
                    (senderMap['_id'] ?? senderMap['id'] ?? senderMap['userId'])
                        ?.toString();
              } else {
                msgSenderId = msg['sender']?.toString();
              }

              final normalizedMsgSenderId = msgSenderId?.trim() ?? '';

              if (normalizedMsgSenderId.isNotEmpty) {
                final senderMatches =
                    normalizedMsgSenderId == normalizedSenderId ||
                    normalizedMsgSenderId == normalizedMyUserId ||
                    normalizedMsgSenderId == normalizedJwtUserId;
                if (!senderMatches) return false;
              }

              try {
                final tempCreatedAt = msg['createdAt']?.toString() ?? '';
                if (tempCreatedAt.isNotEmpty) {
                  final tempTime = DateTime.tryParse(tempCreatedAt);
                  if (tempTime != null) {
                    final timeDiff = DateTime.now().difference(tempTime);

                    if (timeDiff.inSeconds > 10) return false;
                  }
                }
              } catch (e) {}

              return true;
            });

            if (tempMessageIndex != -1) {
            } else {}
          }

          final alreadyExistsById =
              tempMessageIndex == -1 &&
              _localMessages.any(
                (msg) =>
                    msg != null && (msg['_id']?.toString() ?? '') == messageId,
              );

          if (alreadyExistsById) {
            return;
          }

          if (mounted) {
            try {
              setState(() {
                if (tempMessageIndex != -1) {
                  _localMessages[tempMessageIndex] = newMessage;
                } else {
                  final existsById = _localMessages.any(
                    (msg) =>
                        msg != null &&
                        (msg['_id']?.toString() ?? '') == messageId,
                  );

                  if (!existsById) {
                    final content = newMessage['content']?.toString() ?? '';
                    if (content.isNotEmpty && isMyMessage) {
                      final tempIndex = _localMessages.indexWhere((msg) {
                        if (msg == null) return false;
                        final msgId = msg['_id']?.toString() ?? '';
                        if (!msgId.startsWith('temp_')) return false;
                        final msgContent = msg['content']?.toString() ?? '';
                        if (msgContent != content) return false;

                        String? msgSenderId;
                        if (msg['sender'] is Map) {
                          final senderMap = msg['sender'] as Map;
                          msgSenderId =
                              (senderMap['_id'] ??
                                      senderMap['id'] ??
                                      senderMap['userId'])
                                  ?.toString();
                        } else {
                          msgSenderId = msg['sender']?.toString();
                        }

                        final normalizedMsgSenderId = msgSenderId?.trim() ?? '';
                        if (normalizedMsgSenderId.isNotEmpty) {
                          final senderMatches =
                              normalizedMsgSenderId == normalizedSenderId ||
                              normalizedMsgSenderId == normalizedMyUserId ||
                              normalizedMsgSenderId == normalizedJwtUserId;
                          if (!senderMatches) return false;
                        }

                        try {
                          final tempCreatedAt =
                              msg['createdAt']?.toString() ?? '';
                          if (tempCreatedAt.isNotEmpty) {
                            final tempTime = DateTime.tryParse(tempCreatedAt);
                            if (tempTime != null) {
                              final timeDiff = DateTime.now().difference(
                                tempTime,
                              );
                              if (timeDiff.inSeconds > 10) return false;
                            }
                          }
                        } catch (e) {}

                        return true;
                      });

                      if (tempIndex != -1) {
                        _localMessages[tempIndex] = newMessage;
                      } else {
                        _localMessages.add(newMessage);
                        _messageAnimController.forward().then((_) {
                          _messageAnimController.reset();
                        });
                      }
                    } else {
                      _localMessages.add(newMessage);
                      _messageAnimController.forward().then((_) {
                        _messageAnimController.reset();
                      });
                    }
                  } else {}
                }

                _localMessages.sort((a, b) {
                  if (a == null || b == null) return 0;
                  final timeA =
                      DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                      DateTime.now();
                  final timeB =
                      DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                      DateTime.now();
                  return timeA.compareTo(timeB);
                });
              });
            } catch (e) {}
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        } catch (e) {
          _debouncedSoftReload();
        }
      },
      onError: (error) {},
      onDone: () {},
    );
  }

  void _debouncedSoftReload() {
    final now = DateTime.now();

    if (_lastSoftReloadAt == null ||
        now.difference(_lastSoftReloadAt!).inMilliseconds > 500) {
      _lastSoftReloadAt = now;

      _softReloadConversation();
    } else {}
  }

  Future<void> _softReloadConversation({bool forceRefresh = false}) async {
    if (!mounted) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      if (authProvider.token == null) return;

      bool shouldForceRefresh = forceRefresh;
      if (!shouldForceRefresh) {
        try {
          final connectivity = await Connectivity().checkConnectivity();
          final isOnline =
              connectivity.isNotEmpty &&
              connectivity.any((result) => result != ConnectivityResult.none);
          shouldForceRefresh = isOnline;
        } catch (e) {}
      }

      await adminProvider.getConversation(
        widget.userId,
        widget.userType,
        authProvider.token!,
        forceRefresh: shouldForceRefresh,
      );

      if (!mounted) return;

      try {
        setState(() {
          if (adminProvider.messages.isNotEmpty) {
            final messageMap = <String, dynamic>{};

            for (final msg in _localMessages) {
              if (msg == null) continue;
              final msgId = msg['_id']?.toString() ?? '';
              if (msgId.isNotEmpty && !msgId.startsWith('temp_')) {
                messageMap[msgId] = msg;
              }
            }
            final previousCount = messageMap.length;
            for (final message in adminProvider.messages) {
              if (message == null) continue;
              final messageId = message['_id']?.toString() ?? '';
              if (messageId.isNotEmpty) {
                messageMap[messageId] = message;
              }
            }

            final newCount = messageMap.length;
            if (newCount > previousCount) {}

            _localMessages = messageMap.values.toList();
          } else {
            final filteredMessages = <dynamic>[];
            for (final msg in _localMessages) {
              if (msg == null) continue;
              final msgId = msg['_id']?.toString() ?? '';
              if (msgId.isNotEmpty && !msgId.startsWith('temp_')) {
                filteredMessages.add(msg);
              }
            }
            _localMessages = filteredMessages;
          }
          _localMessages.sort((a, b) {
            if (a == null || b == null) return 0;
            final timeA =
                DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
                DateTime.now();
            final timeB =
                DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
                DateTime.now();
            return timeA.compareTo(timeB);
          });
        });

        _scrollToBottom();
      } catch (e) {}
    } catch (e) {}
  }

  void _setupPresenceSubscription() {
    final webSocketService = WebSocketService();
    _presenceSubscription = webSocketService.presenceStream.listen((data) {
      try {
        final event = data['event']?.toString() ?? '';
        final uid =
            (data['userId'] ?? data['id'] ?? data['_id'] ?? data['profileId'])
                ?.toString();
        if (uid == null) return;
        if (uid != widget.userId) return;
        if (event == 'user_connected') {
          setState(() => _isOnline = true);
        } else if (event == 'user_disconnected') {
          setState(() => _isOnline = false);
        }
      } catch (_) {}
    });
  }

  void _setupTypingSubscription() {
    final webSocketService = WebSocketService();
    _typingSubscription = webSocketService.typingStream.listen((data) {
      try {
        final event = data['event']?.toString() ?? '';
        final from = (data['from'] ?? data['senderId'] ?? data['sender'])
            ?.toString();
        if (from == widget.userId) {
          if (event == 'typing_indicator') {
            setState(() => _isPeerTyping = true);
          } else if (event == 'typing_stopped') {
            setState(() => _isPeerTyping = false);
          }
        }
      } catch (_) {}
    });
  }

  Map<String, dynamic> _transformWebSocketData(Map<String, dynamic> data) {
    return {
      '_id': data['messageId'] ?? data['_id'] ?? '',
      'sender': data['sender'] ?? {},
      'receiver': data['receiver'] ?? {},
      'subject': data['subject'] ?? '',
      'content': data['content'] ?? '',
      'messageType': data['messageType'] ?? 'text',
      'priority': data['priority'] ?? 'normal',
      'isRead': false,
      'isApproved': true,
      'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
    };
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    if (!mounted) return;

    setState(() {
      _isSending = true;
    });

    _triggerHaptic();

    try {
      final ws = WebSocketService();
      ws.emitEvent('typing_stopped', {'from': _myUserId, 'to': widget.userId});
    } catch (_) {}

    final messageContent = _messageController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final payload = Jwt.parseJwt(authProvider.token!);
    final senderId = payload['userId'] ?? payload['id'] ?? '';

    final tempMessage = {
      '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender': {'userId': senderId.toString(), 'userType': 'Admin'},
      'receiver': widget.userId,
      'subject': 'Chat Message',
      'content': messageContent,
      'messageType': 'text',
      'priority': 'normal',
      'isRead': false,
      'isApproved': true,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (!mounted) return;
    try {
      setState(() {
        _localMessages.add(tempMessage);
        _localMessages.sort((a, b) {
          final timeA =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
          final timeB =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
          return timeA.compareTo(timeB);
        });
      });
    } catch (e) {
      return;
    }

    _sendController.forward().then((_) {
      _sendController.reset();
    });

    _messageController.clear();
    _scrollToBottom();

    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    try {
      if (widget.userType.toLowerCase() == 'hr') {
        await adminProvider.sendMessageToHR(
          widget.userId,
          'Chat Message',
          messageContent,
          authProvider.token!,
        );
      } else if (widget.userType.toLowerCase() == 'employee') {
        await adminProvider.sendMessageToEmployee(
          widget.userId,
          'Chat Message',
          messageContent,
          authProvider.token!,
        );
      } else {
        throw Exception('Unknown userType: ${widget.userType}');
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          try {
            final tempId = tempMessage['_id']?.toString() ?? '';
            final hasTempMessage =
                tempId.isNotEmpty &&
                _localMessages.any(
                  (msg) => (msg['_id']?.toString() ?? '') == tempId,
                );
            if (hasTempMessage) {
              _softReloadConversation();
            }
          } catch (e) {}
        }
      });
    } catch (e) {
      if (mounted) {
        try {
          setState(() {
            final tempId = tempMessage['_id']?.toString() ?? '';
            if (tempId.isNotEmpty) {
              _localMessages.removeWhere(
                (msg) => (msg['_id']?.toString() ?? '') == tempId,
              );
            }
          });

          SnackBarUtils.showError(
            context,
            'Failed to send message: ${e.toString()}',
          );
        } catch (setStateError) {}
      }
    } finally {
      if (mounted) {
        try {
          setState(() {
            _isSending = false;
          });
        } catch (e) {}
      }
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
    return AppBar(
      backgroundColor: AppColors.edgePrimary,
      elevation: 2,
      shadowColor: Colors.black26,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          _triggerHaptic();
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: Text(
                  widget.userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (_isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.edgePrimary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isPeerTyping
                      ? const Text(
                          'typing...',
                          key: ValueKey('typing'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.greenAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _isOnline ? 'Online' : 'Offline',
                          key: ValueKey(_isOnline ? 'online' : 'offline'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            _triggerHaptic();
          },
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    final adminProvider = Provider.of<AdminProvider>(context);

    if (adminProvider.isLoading && _localMessages.isEmpty) {
      return _buildLoadingState();
    }

    if (adminProvider.error != null && _localMessages.isEmpty) {
      return _buildErrorState(adminProvider.error!);
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
        shrinkWrap: false,
        itemCount: _localMessages.length,
        itemBuilder: (context, index) {
          final message = _localMessages[index];
          String? senderId;
          String? senderUserType;
          if (message['sender'] is Map) {
            senderId =
                message['sender']['userId']?.toString() ??
                message['sender']['_id']?.toString();
            senderUserType = message['sender']['userType']?.toString();
          } else {
            senderId = message['sender']?.toString();
          }

          final isFromMe =
              (senderUserType == 'Admin') ||
              (_myUserId != null && senderId == _myUserId);
          final showDateHeader = _shouldShowDateHeader(index, _localMessages);

          return ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 0,
              maxHeight: double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateHeader)
                  _buildDateHeader(message['createdAt'] ?? ''),
                _buildMessageBubble(message, isFromMe),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _shouldShowDateHeader(int index, List<dynamic> messages) {
    if (index == 0) return true;

    final currentDate =
        DateTime.tryParse(messages[index]['createdAt'] ?? '') ?? DateTime.now();
    final previousDate =
        DateTime.tryParse(messages[index - 1]['createdAt'] ?? '') ??
        DateTime.now();

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  Widget _buildDateHeader(String dateString) {
    final date = DateTime.tryParse(dateString) ?? DateTime.now();
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

  Widget _buildMessageBubble(dynamic message, bool isFromMe) {
    final date =
        DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
    final istTime = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    final time = DateFormat('hh:mm a').format(istTime);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTempMessage =
        message['_id']?.toString().startsWith('temp_') ?? false;
    final content = message['content'] ?? '';
    final subject = message['subject'] ?? '';
    final isApproved = message['isApproved'] ?? true;
    final requiresApproval = message['requiresApproval'] ?? false;

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
                mainAxisAlignment: isFromMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
                    child: Container(
                      margin: EdgeInsets.only(
                        left: isFromMe ? 50 : 8,
                        right: isFromMe ? 8 : 50,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isFromMe
                            ? AppColors.edgePrimary
                            : AppColors.edgeSurface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(8),
                          topRight: const Radius.circular(8),
                          bottomLeft: Radius.circular(isFromMe ? 8 : 2),
                          bottomRight: Radius.circular(isFromMe ? 2 : 8),
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
                          if (subject != 'Chat Message' && subject.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                subject,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFromMe
                                      ? Colors.white.withOpacity(0.9)
                                      : AppColors.edgePrimary,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          Text(
                            content,
                            style: TextStyle(
                              fontSize: 14,
                              color: isFromMe
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
                                  color: isFromMe
                                      ? Colors.white.withOpacity(0.7)
                                      : AppColors.edgeTextSecondary,
                                ),
                              ),
                              if (isFromMe) ...[
                                const SizedBox(width: 4),
                                if (requiresApproval && !isApproved)
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  )
                                else
                                  Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
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
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          _triggerHaptic();
                        },
                        icon: const Icon(
                          Icons.attach_file,
                          color: AppColors.edgePrimary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            setState(() {});
                            if (value.isNotEmpty &&
                                !_typingController.isAnimating) {
                              _typingController.forward().then((_) {
                                _typingController.reverse();
                              });
                            }

                            final ws = WebSocketService();
                            if (value.trim().isNotEmpty) {
                              ws.emitEvent('typing_indicator', {
                                'from': _myUserId,
                                'to': widget.userId,
                              });
                            } else {
                              ws.emitEvent('typing_stopped', {
                                'from': _myUserId,
                                'to': widget.userId,
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
                        final hasText = _messageController.text
                            .trim()
                            .isNotEmpty;
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
                              onPressed: (!hasText) ? null : _sendMessage,
                              icon: const Icon(
                                Icons.send,
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
                            onPressed: () =>
                                _loadConversation(forceRefresh: true),
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

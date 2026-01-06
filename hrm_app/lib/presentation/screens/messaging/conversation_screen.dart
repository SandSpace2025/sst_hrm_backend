import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/core/utils/snackbar_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import '../../providers/network_provider.dart';
import '../../widgets/messaging/message_list_widget.dart';
import '../../widgets/messaging/message_input_widget.dart';
import '../../widgets/common/offline_indicator_widget.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/websocket_provider.dart';

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationScreen({super.key, required this.conversation});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  MessagingProvider? _messagingProvider;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  bool _isPeerTyping = false;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messagingProvider = Provider.of<MessagingProvider>(
        context,
        listen: false,
      );
      _messagingProvider!.setCurrentConversation(widget.conversation);

      _messagingProvider!.loadMessages(forceRefresh: false);
      _messagingProvider!.markConversationAsRead();

      _setupSocketListeners();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _typingSubscription?.cancel();
    _messageSubscription?.cancel();
    _typingDebounce?.cancel();

    _messagingProvider?.clearCurrentConversation();

    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<MessagingProvider>().loadMoreMessages();
    }
  }

  void _onSendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    HapticFeedback.lightImpact();
    _messageController.clear();
    final success = await context.read<MessagingProvider>().sendMessage(
      content: content,
    );

    if (!success && mounted) {
      SnackBarUtils.showError(context, 'Failed to send message');
    }
  }

  void _onTypingChanged(bool isTyping) {
    final webSocketProvider = context.read<WebSocketProvider>();
    final authProvider = context.read<AuthProvider>();

    if (widget.conversation.participants.isEmpty) return;

    // Find the other participant to send typing event to
    final otherParticipant = widget.conversation.participants.firstWhere(
      (p) => p.userId != authProvider.userId,
      orElse: () => widget.conversation.participants.first,
    );

    final data = {
      'conversationId': widget.conversation.conversationId,
      'from': authProvider.userId,
      'to': otherParticipant.userId,
      'event': isTyping ? 'typing_indicator' : 'typing_stopped',
    };

    webSocketProvider.emitEvent(
      isTyping ? 'typing_indicator' : 'typing_stopped',
      data,
    );

    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    if (isTyping) {
      _typingDebounce = Timer(const Duration(milliseconds: 3000), () {
        _onTypingChanged(false);
      });
    }
  }

  void _setupSocketListeners() {
    final webSocketProvider = context.read<WebSocketProvider>();

    // Typing Listener
    _typingSubscription = webSocketProvider.typingStream.listen((data) {
      if (data['conversationId'] == widget.conversation.conversationId) {
        final event = data['event'];
        if (mounted) {
          setState(() {
            _isPeerTyping = event == 'typing_indicator';
          });
        }
      }
    });

    // Message Listener (Real-time updates)
    _messageSubscription = webSocketProvider.messageStream.listen((data) {
      final payload = data['data'] ?? data;
      // Check if message belongs to current conversation
      if (payload['conversationId'] == widget.conversation.conversationId) {
        // Transform payload to Message object
        try {
          if (payload['content'] != null) {
            final message = Message.fromJson(
              Map<String, dynamic>.from(payload),
            );
            if (mounted) {
              context.read<MessagingProvider>().handleMessageReceived(message);
            }
          }
        } catch (e) {
          debugPrint('Error handling real-time message: $e');
          // Fallback to soft refresh only if parsing fails
          if (mounted) {
            context.read<MessagingProvider>().loadMessages(refresh: true);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Column(
        children: [
          Consumer<MessagingProvider>(
            builder: (context, provider, child) {
              final conversation =
                  provider.currentConversation ?? widget.conversation;
              return _buildCustomHeader(conversation);
            },
          ),
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.messages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(
                      5,
                      (index) => ShimmerLoading.listItem(),
                    ),
                  );
                }

                final isOfflineError =
                    provider.error != null &&
                    (provider.error!.toLowerCase().contains(
                          'no internet connection',
                        ) ||
                        provider.error!.toLowerCase().contains(
                          'socketexception',
                        ));

                final networkProvider = Provider.of<NetworkProvider>(
                  context,
                  listen: false,
                );
                final isOffline = !networkProvider.isOnline;

                if ((isOfflineError || isOffline) &&
                    provider.messages.isEmpty &&
                    !provider.isLoading) {
                  return const OfflineIndicatorWidget(message: 'No internet');
                }

                if (provider.error != null && !isOfflineError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            provider.clearError();

                            await _refreshMessages();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Start a conversation',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to begin chatting',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return MessageListWidget(
                  messages: provider.messages,
                  scrollController: _scrollController,
                  onLoadMore: () => provider.loadMoreMessages(),
                  hasMoreMessages: provider.hasMoreMessages,
                  isLoadingMore: provider.isLoading,
                  currentUserId: Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).userId,
                );
              },
            ),
          ),
          MessageInputWidget(
            controller: _messageController,
            onSend: _onSendMessage,
            onTypingChanged: _onTypingChanged,
            enabled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(Conversation conversation) {
    final topPadding = MediaQuery.of(context).padding.top;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.userId;

      final title = conversation.title;

      String role = 'Member';
      Participant? targetParticipant;

      if (conversation.participants.isNotEmpty) {
        targetParticipant = conversation.participants.firstWhere(
          (p) => p.userId != currentUserId,
          orElse: () => conversation.participants.first,
        );

        final type = targetParticipant.userType;
        if (type.isNotEmpty) {
          role = type[0].toUpperCase() + type.substring(1);
        }
        if (type.toLowerCase() == 'hr') role = 'HR Manager';
      }

      // Use WebSocketProvider for accurate real-time presence
      final webSocketProvider = Provider.of<WebSocketProvider>(context);
      final isOnline =
          targetParticipant != null &&
          webSocketProvider.isOnlineId(targetParticipant.userId);

      // Image Lookup Logic
      String? profileImageUrl;
      if (targetParticipant != null) {
        try {
          final employeeProvider = Provider.of<EmployeeProvider>(
            context,
            listen: false,
          );
          final allContacts = [
            ...employeeProvider.employeeContacts,
            ...employeeProvider.hrContacts,
            ...employeeProvider.adminContacts,
          ];

          debugPrint(
            'Looking for photo for UserID: ${targetParticipant!.userId}',
          );
          debugPrint('Total contacts available: ${allContacts.length}');

          final contact = allContacts.firstWhere((c) {
            final id = c['_id'] ?? c['id'] ?? '';
            return id.toString() == targetParticipant!.userId.toString();
          }, orElse: () => null);

          if (contact != null) {
            debugPrint(
              'Found contact: ${contact['name']}, Image: ${contact['profileImage']}',
            );
          } else {
            debugPrint('Contact not found in provider list');
          }

          // Check both keys: profilePic (often used) and profileImage
          final rawPic = contact != null
              ? (contact['profilePic'] ?? contact['profileImage'] ?? '')
                    .toString()
              : '';

          if (rawPic.isNotEmpty) {
            if (rawPic.startsWith('http')) {
              profileImageUrl = rawPic;
            } else {
              // Logic copied from EmployeeWhatsAppContactsScreen
              String baseUrl = const String.fromEnvironment(
                'APP_BASE_URL',
                defaultValue: 'http://192.168.29.30:5000',
              );

              if (baseUrl.endsWith('/')) {
                baseUrl = baseUrl.substring(0, baseUrl.length - 1);
              }
              if (baseUrl.endsWith('/api')) {
                baseUrl = baseUrl.substring(0, baseUrl.length - 4);
              }

              String path = rawPic.replaceAll(r'\', '/');

              if (path.contains('uploads/')) {
                final index = path.indexOf('uploads/');
                path = path.substring(index);
              } else if (!path.contains('/')) {
                path = 'uploads/profiles/$path';
              }

              if (path.startsWith('/')) {
                path = path.substring(1);
              }

              profileImageUrl = '$baseUrl/$path';
            }
            debugPrint('ConversationScreen: Final Image URL: $profileImageUrl');
          }
        } catch (e) {
          debugPrint('Error loading profile image in header: $e');
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 26,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null
                  ? Text(
                      title.isNotEmpty ? title[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPeerTyping) ...[
                    const Text(
                      'Typing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.circle,
                      color: isOnline ? Colors.white : Colors.grey[400],
                      size: 8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error building custom header: $e');
      return Container(
        height: 80 + topPadding,
        padding: EdgeInsets.only(top: topPadding),
        color: AppColors.primary,
        child: const Center(
          child: Text('Chat', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _showConversationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.conversation.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${widget.conversation.conversationType}'),
            Text('Messages: ${widget.conversation.messageCount}'),
            Text('Created: ${_formatDate(widget.conversation.createdAt)}'),
            const SizedBox(height: 16),
            const Text(
              'Participants:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...widget.conversation.activeParticipants.map(
              (participant) => ListTile(
                leading: CircleAvatar(
                  child: Text(participant.userType[0].toUpperCase()),
                ),
                title: Text(participant.userType),
                subtitle: Text(participant.userId),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddParticipantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Participant'),
        content: const Text('This feature requires user selection interface.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRemoveParticipantDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: const Text(
          'This feature requires participant selection interface.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _refreshMessages() async {
    final provider = Provider.of<MessagingProvider>(context, listen: false);
    final networkProvider = Provider.of<NetworkProvider>(
      context,
      listen: false,
    );

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline =
        connectivity.isNotEmpty &&
        connectivity.any((result) => result != ConnectivityResult.none);

    if (!isOnline && !networkProvider.isOnline) {
      if (mounted) SnackBarUtils.showError(context, 'No internet connection');
      return;
    }

    if (mounted) SnackBarUtils.showInfo(context, 'Refreshing messages...');

    await provider.refreshMessages();

    if (!mounted) return;

    if (provider.error != null &&
        (provider.error!.toLowerCase().contains('no internet connection') ||
            provider.error!.toLowerCase().contains('socketexception'))) {
      SnackBarUtils.showError(context, 'No internet connection');
    } else if (provider.error == null && provider.messages.isNotEmpty) {
      SnackBarUtils.showSuccess(context, 'Messages refreshed');
    }
  }
}

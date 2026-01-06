import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/conversation.dart';
import '../../providers/messaging_provider.dart';

class ConversationListWidget extends StatefulWidget {
  const ConversationListWidget({super.key});

  @override
  State<ConversationListWidget> createState() => _ConversationListWidgetState();
}

class _ConversationListWidgetState extends State<ConversationListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {

      context.read<MessagingProvider>().loadConversations(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<MessagingProvider>().loadMoreConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.conversations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading conversations',
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

                    await provider.refreshConversations();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation with your colleagues',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshConversations(),
          child: ListView.builder(
            controller: _scrollController,
            itemCount:
                provider.conversations.length + (provider.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.conversations.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final conversation = provider.conversations[index];
              return ConversationListItem(
                conversation: conversation,
                onTap: () {
                  provider.setCurrentConversation(conversation);

                  Navigator.pushNamed(
                    context,
                    '/conversation',
                    arguments: conversation,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = conversation.unreadCount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getConversationColor(conversation.conversationType),
          child: Text(
            conversation.title.isNotEmpty
                ? conversation.title[0].toUpperCase()
                : 'C',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          conversation.title,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.description.isNotEmpty)
              Text(
                conversation.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getConversationIcon(conversation.conversationType),
                  size: 12,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  _getConversationTypeText(conversation.conversationType),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _formatLastMessageTime(conversation.lastMessageAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isUnread)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${conversation.messageCount} messages',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Color _getConversationColor(String type) {
    switch (type) {
      case 'direct':
        return Colors.blue;
      case 'group':
        return Colors.green;
      case 'support':
        return Colors.orange;
      case 'announcement':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getConversationIcon(String type) {
    switch (type) {
      case 'direct':
        return Icons.person;
      case 'group':
        return Icons.group;
      case 'support':
        return Icons.support_agent;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.chat;
    }
  }

  String _getConversationTypeText(String type) {
    switch (type) {
      case 'direct':
        return 'Direct';
      case 'group':
        return 'Group';
      case 'support':
        return 'Support';
      case 'announcement':
        return 'Announcement';
      default:
        return 'Chat';
    }
  }

  String _formatLastMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

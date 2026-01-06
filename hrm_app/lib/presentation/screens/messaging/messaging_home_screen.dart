import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/messaging_provider.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';
import '../../widgets/messaging/messaging_debug_widget.dart';
import 'new_conversation_screen.dart';

class MessagingHomeScreen extends StatefulWidget {
  const MessagingHomeScreen({super.key});

  @override
  State<MessagingHomeScreen> createState() => _MessagingHomeScreenState();
}

class _MessagingHomeScreenState extends State<MessagingHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _conversationTypeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      const authToken = 'your_auth_token_here';
      context.read<MessagingProvider>().initializeMessaging(authToken);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: _showSearchDialog,
            icon: const Icon(Icons.search),
            tooltip: 'Search Conversations',
          ),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Conversations',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All', icon: Icon(Icons.chat)),
            Tab(text: 'Direct', icon: Icon(Icons.person)),
            Tab(text: 'Groups', icon: Icon(Icons.group)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (kDebugMode) ...[
            const MessagingDebugWidget(
              authToken: null,
              testParticipants: [
                {
                  'userId': 'test_hr_1',
                  'userType': 'HR',
                  'name': 'Test HR User',
                  'email': 'hr@test.com',
                },
                {
                  'userId': 'test_admin_1',
                  'userType': 'Admin',
                  'name': 'Test Admin User',
                  'email': 'admin@test.com',
                },
              ],
            ),
          ],

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConversationList('all'),
                _buildConversationList('direct'),
                _buildConversationList('group'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        tooltip: 'New Conversation',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildConversationList(String type) {
    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.conversations.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(5, (index) => ShimmerLoading.listItem()),
          );
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
                  onPressed: () {
                    provider.clearError();
                    provider.refreshConversations();
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
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createNewConversation,
                  icon: const Icon(Icons.add),
                  label: const Text('Start Conversation'),
                ),
              ],
            ),
          );
        }

        final filteredConversations = provider.conversations.where((
          conversation,
        ) {
          if (type == 'all') return true;
          return conversation.conversationType == type;
        }).toList();

        if (filteredConversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No $type conversations',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new $type conversation to get started',
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
            itemCount: filteredConversations.length,
            itemBuilder: (context, index) {
              final conversation = filteredConversations[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  onTap: () => _openConversation(conversation),
                  leading: CircleAvatar(
                    backgroundColor: _getConversationColor(
                      conversation.conversationType,
                    ),
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
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
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
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _getConversationIcon(conversation.conversationType),
                            size: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getConversationTypeText(
                              conversation.conversationType,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Text(
                            _formatLastMessageTime(conversation.lastMessageAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _createNewConversation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewConversationScreen()),
    );
  }

  void _openConversation(conversation) {
    Navigator.pushNamed(context, '/conversation', arguments: conversation);
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Conversations'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter search query',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {},
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Conversations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All'),
              value: 'all',
              groupValue: _conversationTypeFilter,
              onChanged: (value) {
                setState(() {
                  _conversationTypeFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Direct'),
              value: 'direct',
              groupValue: _conversationTypeFilter,
              onChanged: (value) {
                setState(() {
                  _conversationTypeFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Group'),
              value: 'group',
              groupValue: _conversationTypeFilter,
              onChanged: (value) {
                setState(() {
                  _conversationTypeFilter = value!;
                });
                Navigator.pop(context);
              },
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

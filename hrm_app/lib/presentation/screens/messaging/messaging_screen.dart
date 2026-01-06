import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../widgets/messaging/conversation_list_widget.dart';
import '../../widgets/messaging/new_conversation_dialog.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MessagingProvider>().refreshConversations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showNewConversationDialog();
            },
          ),
        ],
      ),
      body: const ConversationListWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewConversationDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }
}

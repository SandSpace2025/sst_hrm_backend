import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/conversation.dart';
import '../../providers/messaging_provider.dart';
import 'user_selection_widget.dart';

class NewConversationDialog extends StatefulWidget {
  const NewConversationDialog({super.key});

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _conversationType = 'direct';
  List<Participant> _selectedUsers = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onUsersSelected(List<Participant> users) {
    setState(() {
      _selectedUsers = users;
    });
  }

  Future<void> _createConversation() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a conversation title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one participant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final success = await context
          .read<MessagingProvider>()
          .createConversation(
            participants: _selectedUsers.map((u) => u.toJson()).toList(),
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            conversationType: _conversationType,
          );

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Conversation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),


            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter conversation title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter conversation description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),


            DropdownButtonFormField<String>(
              initialValue: _conversationType,
              decoration: const InputDecoration(
                labelText: 'Conversation Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'direct', child: Text('Direct')),
                DropdownMenuItem(value: 'group', child: Text('Group')),
                DropdownMenuItem(value: 'support', child: Text('Support')),
                DropdownMenuItem(
                  value: 'announcement',
                  child: Text('Announcement'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _conversationType = value ?? 'direct';
                });
              },
            ),
            const SizedBox(height: 16),


            Text(
              'Select Participants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            Expanded(
              child: UserSelectionWidget(
                onUserSelected: (user) {
                  _onUsersSelected([Participant.fromJson(user)]);
                },
                excludeUsers: _selectedUsers.map((p) => p.toJson()).toList(),
              ),
            ),

            const SizedBox(height: 16),


            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _createConversation,
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

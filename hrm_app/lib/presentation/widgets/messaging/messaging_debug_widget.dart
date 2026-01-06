import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';

class MessagingDebugWidget extends StatefulWidget {
  final String? authToken;
  final List<Map<String, dynamic>>? testParticipants;

  const MessagingDebugWidget({super.key, this.authToken, this.testParticipants});

  @override
  State<MessagingDebugWidget> createState() => _MessagingDebugWidgetState();
}

class _MessagingDebugWidgetState extends State<MessagingDebugWidget> {
  bool _isRunning = false;
  Map<String, dynamic>? _testResults;
  String _status = 'Ready to test';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Messaging Debug',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isRunning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_testResults != null) ...[
              const Text(
                'Test Results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildTestResults(),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runQuickDiagnostic,
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Quick Diagnostic'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runFullTest,
                    icon: const Icon(Icons.science),
                    label: const Text('Full Test'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Consumer<MessagingProvider>(
              builder: (context, provider, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provider State:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Loading: ${provider.isLoading}'),
                      Text('Error: ${provider.error ?? "None"}'),
                      Text('Conversations: ${provider.conversations.length}'),
                      Text('Messages: ${provider.messages.length}'),
                      Text(
                        'Current Conversation: ${provider.currentConversation?.title ?? "None"}',
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTestResults() {
    final results = <Widget>[];

    _testResults!.forEach((key, value) {
      if (key == 'summary') return;

      final isSuccess = value is Map && value['success'] == true;
      results.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSuccess ? Colors.green : Colors.red),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    key.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green[800] : Colors.red[800],
                    ),
                  ),
                ],
              ),
              if (value is Map && value['error'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${value['error']}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
              if (value is Map && value['statusCode'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Status: ${value['statusCode']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    });

    return results;
  }

  Color _getStatusColor() {
    if (_isRunning) return Colors.blue;
    if (_testResults == null) return Colors.grey;

    final summary = _testResults!['summary'];
    if (summary != null && summary['success'] == true) {
      return Colors.green;
    }
    return Colors.red;
  }

  Future<void> _runQuickDiagnostic() async {
    if (widget.authToken == null) {
      _setStatus('❌ No auth token provided', Colors.red);
      return;
    }

    setState(() {
      _isRunning = true;
      _status = 'Running quick diagnostic...';
    });
  }

  Future<void> _runFullTest() async {
    if (widget.authToken == null) {
      _setStatus('❌ No auth token provided', Colors.red);
      return;
    }

    setState(() {
      _isRunning = true;
      _status = 'Running full test...';
      _testResults = null;
    });
  }

  void _setStatus(String status, Color color) {
    setState(() {
      _status = status;
    });
  }
}

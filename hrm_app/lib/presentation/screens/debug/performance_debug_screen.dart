import 'package:flutter/material.dart';
import 'package:hrm_app/core/services/optimized_api_service.dart';

class PerformanceDebugScreen extends StatefulWidget {
  const PerformanceDebugScreen({super.key});

  @override
  State<PerformanceDebugScreen> createState() => _PerformanceDebugScreenState();
}

class _PerformanceDebugScreenState extends State<PerformanceDebugScreen> {
  Map<String, dynamic> _apiStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);

    await OptimizedApiService.clearAllCache();

    setState(() {
      _isLoading = false;
      _apiStats = {};
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared and stats reset'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Debug'),
        backgroundColor: const Color(0xFF0F6CBD),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _clearCache, icon: const Icon(Icons.clear_all)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildEndpointsCard(),
                  const SizedBox(height: 16),
                  _buildLastCallsCard(),
                  const SizedBox(height: 16),
                  _buildDurationsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final totalCalls = _apiStats['totalCalls'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Call Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total API Calls: $totalCalls'),
            const SizedBox(height: 8),
            Text(
              'Unique Endpoints: ${(_apiStats['endpoints'] as Map?)?.length ?? 0}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointsCard() {
    final endpoints = _apiStats['endpoints'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endpoint Call Counts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (endpoints.isEmpty)
              const Text('No API calls recorded yet')
            else
              ...endpoints.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCallCountColor(entry.value),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastCallsCard() {
    final lastCalls = _apiStats['lastCalls'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Call Times',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (lastCalls.isEmpty)
              const Text('No API calls recorded yet')
            else
              ...lastCalls.entries.map((entry) {
                final lastCall = DateTime.fromMillisecondsSinceEpoch(
                  entry.value,
                );
                final timeAgo = DateTime.now().difference(lastCall);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(timeAgo),
                        style: TextStyle(
                          color: _getTimeAgoColor(timeAgo),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationsCard() {
    final durations = _apiStats['durations'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'API Call Durations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (durations.isEmpty)
              const Text('No API calls recorded yet')
            else
              ...durations.entries.map((entry) {
                final duration = entry.value as Duration;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getDurationColor(duration),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${duration.inMilliseconds}ms',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Color _getCallCountColor(int count) {
    if (count <= 5) return Colors.green;
    if (count <= 15) return Colors.orange;
    return Colors.red;
  }

  Color _getTimeAgoColor(Duration timeAgo) {
    if (timeAgo.inMinutes < 5) return Colors.green;
    if (timeAgo.inMinutes < 30) return Colors.orange;
    return Colors.red;
  }

  Color _getDurationColor(Duration duration) {
    if (duration.inMilliseconds < 500) return Colors.green;
    if (duration.inMilliseconds < 2000) return Colors.orange;
    return Colors.red;
  }

  String _formatTimeAgo(Duration timeAgo) {
    if (timeAgo.inSeconds < 60) {
      return '${timeAgo.inSeconds}s ago';
    } else if (timeAgo.inMinutes < 60) {
      return '${timeAgo.inMinutes}m ago';
    } else {
      return '${timeAgo.inHours}h ago';
    }
  }
}

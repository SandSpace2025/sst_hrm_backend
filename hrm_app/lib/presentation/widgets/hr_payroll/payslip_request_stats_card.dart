import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayslipRequestStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isLoading;

  const PayslipRequestStatsCard({
    super.key,
    required this.stats,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Requests',
                  stats['total']?.toString() ?? '0',
                  Icons.request_page,
                  AppColors.edgePrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  stats['pending']?.toString() ?? '0',
                  Icons.pending,
                  AppColors.edgeWarning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Processing',
                  stats['processing']?.toString() ?? '0',
                  Icons.hourglass_empty,
                  AppColors.edgePrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  stats['completed']?.toString() ?? '0',
                  Icons.check_circle,
                  AppColors.edgeAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
                const SizedBox(height: 16),
                if (stats['breakdown'] != null &&
                    (stats['breakdown'] as List).isNotEmpty)
                  ...((stats['breakdown'] as List).map(
                    (item) => _buildBreakdownItem(item),
                  ))
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeTextSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.edgeDivider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetricItem(
                  'Completion Rate',
                  _calculateCompletionRate(),
                  Icons.trending_up,
                  AppColors.edgeAccent,
                ),
                const SizedBox(height: 12),
                _buildMetricItem(
                  'Average Processing Time',
                  '2-3 days',
                  Icons.schedule,
                  AppColors.edgePrimary,
                ),
                const SizedBox(height: 12),
                _buildMetricItem(
                  'Pending Requests',
                  '${stats['pending'] ?? 0}',
                  Icons.pending_actions,
                  AppColors.edgeWarning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.edgeTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(Map<String, dynamic> item) {
    final status = item['_id'] ?? 'unknown';
    final count = item['count'] ?? 0;
    final color = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusLabel(status).toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.edgeText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.edgeWarning;
      case 'processing':
        return AppColors.edgePrimary;
      case 'completed':
        return AppColors.edgeAccent;
      case 'rejected':
        return AppColors.edgeError;
      case 'on-hold':
      case 'on_hold':
        return AppColors.edgeWarning;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Processing';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'on-hold':
      case 'on_hold':
        return 'Hold';
      default:
        return status;
    }
  }

  String _calculateCompletionRate() {
    final total = stats['total'] ?? 0;
    final completed = stats['completed'] ?? 0;

    if (total == 0) return '0%';

    final rate = (completed / total * 100).round();
    return '$rate%';
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/leave_request_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveRequestStatsWidget extends StatelessWidget {
  final bool isSmallDevice;

  const LeaveRequestStatsWidget({super.key, required this.isSmallDevice});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveRequestProvider>(
      builder: (context, leaveRequestProvider, child) {
        final stats = leaveRequestProvider.stats;

        if (stats == null) {
          return const SizedBox.shrink();
        }

        final statsData = stats['stats'] as Map<String, dynamic>? ?? {};

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total',
                count: statsData['total']?.toString() ?? '0',
                color: AppColors.edgePrimary,
                icon: Icons.list_alt_rounded,
                isSmallDevice: isSmallDevice,
              ),
            ),
            SizedBox(width: isSmallDevice ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                title: 'Pending',
                count: statsData['pending']?.toString() ?? '0',
                color: AppColors.edgeWarning,
                icon: Icons.pending_rounded,
                isSmallDevice: isSmallDevice,
              ),
            ),
            SizedBox(width: isSmallDevice ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                title: 'Approved',
                count: statsData['approved']?.toString() ?? '0',
                color: AppColors.edgeAccent,
                icon: Icons.check_circle_rounded,
                isSmallDevice: isSmallDevice,
              ),
            ),
            SizedBox(width: isSmallDevice ? 8 : 12),
            Expanded(
              child: _buildStatCard(
                title: 'Rejected',
                count: statsData['rejected']?.toString() ?? '0',
                color: AppColors.edgeError,
                icon: Icons.cancel_rounded,
                isSmallDevice: isSmallDevice,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
    required bool isSmallDevice,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallDevice ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isSmallDevice ? 14 : 16),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: isSmallDevice ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallDevice ? 10 : 11,
              color: AppColors.edgeText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

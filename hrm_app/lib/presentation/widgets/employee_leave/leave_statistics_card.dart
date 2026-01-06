import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveStatisticsCard extends StatelessWidget {
  const LeaveStatisticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final statistics = employeeProvider.leaveStatistics;
        if (statistics == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.edgeDivider),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.edgePrimary),
            ),
          );
        }

        final currentMonthLeaves = statistics['currentMonthLeaves'] ?? 0;
        final pendingLeaves = statistics['pendingLeaves'] ?? 0;
        final approvedLeaves = statistics['approvedLeaves'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.edgeText.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: AppColors.edgePrimary,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Leave Statistics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.edgeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'This Month',
                      currentMonthLeaves.toString(),
                      AppColors.edgePrimary,
                      Icons.calendar_month_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      'Pending',
                      pendingLeaves.toString(),
                      AppColors.edgeWarning,
                      Icons.pending_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                'Approved',
                approvedLeaves.toString(),
                AppColors.edgeAccent,
                Icons.check_circle_outline,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.edgeTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

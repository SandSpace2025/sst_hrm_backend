import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class BlackoutDatesCard extends StatelessWidget {
  const BlackoutDatesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final blackoutDates = employeeProvider.blackoutDates;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.edgeDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.block_outlined,
                    color: AppColors.edgeError,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Blackout Dates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.edgeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (blackoutDates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.edgeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.edgeAccent.withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.edgeAccent,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No blackout dates currently active',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.edgeText,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...blackoutDates.map(
                  (blackout) => _buildBlackoutDateItem(blackout),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlackoutDateItem(Map<String, dynamic> blackout) {
    final startDate = blackout['startDate'] ?? '';
    final endDate = blackout['endDate'] ?? '';
    final reason = blackout['reason'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.edgeError.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.edgeError.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_busy, size: 14, color: AppColors.edgeError),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgeText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.edgeTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

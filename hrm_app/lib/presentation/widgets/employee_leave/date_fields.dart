import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class DateFields extends StatelessWidget {
  final String selectedDurationType;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;

  const DateFields({
    super.key,
    required this.selectedDurationType,
    required this.startDate,
    required this.endDate,
    required this.onStartDateTap,
    required this.onEndDateTap,
  });
  @override
  Widget build(BuildContext context) {
    if (selectedDurationType == 'hours') {
      return _buildDateField(
        label: 'Date',
        date: startDate,
        onTap: onStartDateTap,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildDateField(
            label: 'Start Date',
            date: startDate,
            onTap: onStartDateTap,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateField(
            label: 'End Date',
            date: endDate,
            onTap: onEndDateTap,
            enabled: startDate != null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.edgeText : AppColors.edgeTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: enabled ? AppColors.edgeSurface : AppColors.edgeBackground,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: enabled
                    ? AppColors.edgeDivider
                    : AppColors.edgeDivider.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: enabled
                      ? AppColors.edgeTextSecondary
                      : AppColors.edgeTextSecondary.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 13,
                      color: date != null
                          ? AppColors.edgeText
                          : AppColors.edgeTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: enabled
                      ? AppColors.edgeTextSecondary
                      : AppColors.edgeTextSecondary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

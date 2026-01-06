import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class DurationTypeField extends StatelessWidget {
  final String selectedDurationType;
  final String selectedLeaveType;
  final ValueChanged<String> onChanged;

  DurationTypeField({
    super.key,
    required this.selectedDurationType,
    required this.selectedLeaveType,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> _durationTypes = [
    {
      'value': 'full_day',
      'label': 'Full Day',
      'icon': Icons.calendar_today_outlined,
    },
    {'value': 'half_day', 'label': 'Half Day', 'icon': Icons.schedule_outlined},
    {'value': 'hours', 'label': 'Hours', 'icon': Icons.timer_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Duration Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.edgeDivider),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: selectedDurationType,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.edgeText,
              fontWeight: FontWeight.w500,
            ),
            items: _durationTypes
                .where((type) {
                  if (selectedLeaveType == 'permission') {
                    return type['value'] == 'hours';
                  } else if (selectedLeaveType == 'sick') {
                    return type['value'] == 'full_day';
                  } else {
                    return type['value'] != 'hours';
                  }
                })
                .map((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Row(
                      children: [
                        Icon(
                          type['icon'],
                          size: 16,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            type['label'],
                            style: const TextStyle(
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
                  );
                })
                .toList(),
            onChanged: (value) => onChanged(value!),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class HalfDayPeriodField extends StatelessWidget {
  final String selectedHalfDayPeriod;
  final ValueChanged<String> onChanged;

  HalfDayPeriodField({
    super.key,
    required this.selectedHalfDayPeriod,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> _halfDayPeriods = [
    {'value': 'first_half', 'label': '10:00 AM - 2:30 PM'},
    {'value': 'second_half', 'label': '2:30 PM - 7:00 PM'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Half Day Period',
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
            initialValue: selectedHalfDayPeriod,
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
            items: _halfDayPeriods.map((period) {
              return DropdownMenuItem<String>(
                value: period['value'],
                child: Text(
                  period['label'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) => onChanged(value!),
          ),
        ),
      ],
    );
  }
}

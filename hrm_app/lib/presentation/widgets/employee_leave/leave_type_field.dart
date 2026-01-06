import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveTypeField extends StatelessWidget {
  final String selectedLeaveType;
  final ValueChanged<String> onChanged;

  LeaveTypeField({
    super.key,
    required this.selectedLeaveType,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> _leaveTypes = [
    {
      'value': 'casual',
      'label': 'Casual Leave',
      'icon': Icons.event_outlined,
      'color': AppColors.edgeAccent,
    },
    {
      'value': 'sick',
      'label': 'Sick Leave',
      'icon': Icons.health_and_safety_outlined,
      'color': AppColors.edgeError,
      'requiresMedicalCertificate': true,
      'onlyFullDay': true,
    },
    {
      'value': 'work_from_home',
      'label': 'Work from Home',
      'icon': Icons.home_outlined,
      'color': AppColors.edgePrimary,
    },
    {
      'value': 'permission',
      'label': 'Permission (Hours)',
      'icon': Icons.access_time_outlined,
      'color': AppColors.edgeWarning,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave Type',
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
            initialValue: selectedLeaveType,
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
            items: _leaveTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type['value'],
                child: Row(
                  children: [
                    Icon(type['icon'], size: 16, color: type['color']),
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
            }).toList(),
            onChanged: (value) => onChanged(value!),
          ),
        ),
      ],
    );
  }
}

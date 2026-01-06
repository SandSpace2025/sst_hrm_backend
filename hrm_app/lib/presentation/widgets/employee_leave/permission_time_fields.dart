import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PermissionTimeFields extends StatelessWidget {
  final TimeOfDay permissionStartTime;
  final TimeOfDay permissionEndTime;
  final VoidCallback onStartTimeTap;
  final VoidCallback onEndTimeTap;

  const PermissionTimeFields({
    super.key,
    required this.permissionStartTime,
    required this.permissionEndTime,
    required this.onStartTimeTap,
    required this.onEndTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeField(
            context,
            label: 'Start Time',
            time: permissionStartTime,
            onTap: onStartTimeTap,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTimeField(
            context,
            label: 'End Time',
            time: permissionEndTime,
            onTap: onEndTimeTap,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.edgeDivider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.edgeTextSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

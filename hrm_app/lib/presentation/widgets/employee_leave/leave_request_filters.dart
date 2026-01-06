import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveRequestFilters extends StatelessWidget {
  final String filterStatus;
  final String filterLeaveType;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onLeaveTypeChanged;

  LeaveRequestFilters({
    super.key,
    required this.filterStatus,
    required this.filterLeaveType,
    required this.onStatusChanged,
    required this.onLeaveTypeChanged,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  final List<Map<String, dynamic>> _leaveTypes = [
    {
      'value': 'casual',
      'label': 'Casual Leave',
      'icon': Icons.event_rounded,
      'description': '1 per month, carries over',
      'color': AppColors.edgeAccent,
    },
    {
      'value': 'sick',
      'label': 'Sick Leave',
      'icon': Icons.health_and_safety_rounded,
      'description': 'Unlimited, tracked',
      'color': AppColors.edgeError,
    },
    {
      'value': 'work_from_home',
      'label': 'Work from Home',
      'icon': Icons.home_rounded,
      'description': '1 per month, resets monthly',
      'color': AppColors.edgePrimary,
    },
    {
      'value': 'permission',
      'label': 'Permission (Hours)',
      'icon': Icons.access_time_rounded,
      'description': '3 hours per month, resets monthly',
      'color': AppColors.edgeWarning,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.edgePrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.edgeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Status',
                  value: filterStatus,
                  items: _buildStatusItems(),
                  onChanged: (value) {
                    _triggerHaptic();
                    onStatusChanged(value!);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Leave Type',
                  value: filterLeaveType,
                  items: _buildLeaveTypeItems(),
                  onChanged: (value) {
                    _triggerHaptic();
                    onLeaveTypeChanged(value!);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.edgeDivider, width: 1),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.edgeText,
              fontWeight: FontWeight.w500,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.edgeTextSecondary,
              size: 20,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildStatusItems() {
    return [
      DropdownMenuItem(
        value: 'all',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeTextSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'All Status',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'pending',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeWarning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pending',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'approved',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Approved',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'rejected',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeError,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Rejected',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'cancelled',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeTextSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Cancelled',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _buildLeaveTypeItems() {
    return [
      DropdownMenuItem(
        value: 'all',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgeTextSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'All Types',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      ..._leaveTypes.map(
        (type) => DropdownMenuItem(
          value: type['value'],
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: type['color'],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type['label'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeText,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

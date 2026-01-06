import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveRequestFiltersWidget extends StatelessWidget {
  final String? selectedStatus;
  final String? selectedLeaveType;
  final Function(String?) onStatusChanged;
  final Function(String?) onLeaveTypeChanged;

  const LeaveRequestFiltersWidget({
    super.key,
    this.selectedStatus,
    this.selectedLeaveType,
    required this.onStatusChanged,
    required this.onLeaveTypeChanged,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isSmallDevice ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.04),
            blurRadius: 8,
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
                width: isSmallDevice ? 36 : 40,
                height: isSmallDevice ? 36 : 40,
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  color: AppColors.edgePrimary,
                  size: isSmallDevice ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.edgeText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Filter leave requests by status and type',
                      style: TextStyle(
                        fontSize: isSmallDevice ? 12 : 13,
                        color: AppColors.edgeTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                  value: selectedStatus,
                  items: _buildStatusItems(),
                  onChanged: (value) {
                    _triggerHaptic();
                    onStatusChanged(value);
                  },
                  isSmallDevice: isSmallDevice,
                ),
              ),
              SizedBox(width: isSmallDevice ? 12 : 16),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Leave Type',
                  value: selectedLeaveType,
                  items: _buildLeaveTypeItems(),
                  onChanged: (value) {
                    _triggerHaptic();
                    onLeaveTypeChanged(value);
                  },
                  isSmallDevice: isSmallDevice,
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
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required bool isSmallDevice,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallDevice ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppColors.edgeText,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallDevice ? 12 : 16,
            vertical: isSmallDevice ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.edgeDivider, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.edgeText.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.edgeTextSecondary,
                size: isSmallDevice ? 18 : 20,
              ),
              style: TextStyle(
                fontSize: isSmallDevice ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildStatusItems() {
    return [
      DropdownMenuItem(
        value: null,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
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
        value: null,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'sick',
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
              'Sick Leave',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'vacation',
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
              'Vacation',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'personal',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.edgePrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Personal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'maternity',
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
              'Maternity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'paternity',
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
              'Paternity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'bereavement',
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
              'Bereavement',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'medical',
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
              'Medical',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'other',
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
              'Other',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

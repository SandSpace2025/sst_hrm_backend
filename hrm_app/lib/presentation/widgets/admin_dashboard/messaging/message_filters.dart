import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class MessageFilters extends StatefulWidget {
  final Function(String?, String?, String?, bool) onFiltersChanged;

  const MessageFilters({super.key, required this.onFiltersChanged});

  @override
  State<MessageFilters> createState() => _MessageFiltersState();
}

class _MessageFiltersState extends State<MessageFilters> {
  String? _messageType;
  String? _status;
  String? _priority;
  bool _showArchived = false;

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  int get _activeFilterCount {
    return (_messageType != null ? 1 : 0) +
        (_status != null ? 1 : 0) +
        (_priority != null ? 1 : 0) +
        (_showArchived ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        _triggerHaptic();
        if (value == 'clear') {
          setState(() {
            _messageType = null;
            _status = null;
            _priority = null;
            _showArchived = false;
          });
          widget.onFiltersChanged(null, null, null, false);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'Filters',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              fontSize: 14,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.edgeText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFilterChip('All', null, _messageType == null, 'type'),
                  _buildFilterChip(
                    'To Employee',
                    'admin_to_employee',
                    _messageType == 'admin_to_employee',
                    'type',
                  ),
                  _buildFilterChip(
                    'To HR',
                    'admin_to_hr',
                    _messageType == 'admin_to_hr',
                    'type',
                  ),
                  _buildFilterChip(
                    'From HR',
                    'hr_to_admin',
                    _messageType == 'hr_to_admin',
                    'type',
                  ),
                  _buildFilterChip(
                    'From Employee',
                    'employee_to_admin',
                    _messageType == 'employee_to_admin',
                    'type',
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.edgeText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFilterChip('All', null, _status == null, 'status'),
                  _buildFilterChip(
                    'Unread',
                    'unread',
                    _status == 'unread',
                    'status',
                  ),
                  _buildFilterChip('Read', 'read', _status == 'read', 'status'),
                  _buildFilterChip('Sent', 'sent', _status == 'sent', 'status'),
                  _buildFilterChip(
                    'Delivered',
                    'delivered',
                    _status == 'delivered',
                    'status',
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Priority',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.edgeText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFilterChip('All', null, _priority == null, 'priority'),
                  _buildFilterChip(
                    'Low',
                    'low',
                    _priority == 'low',
                    'priority',
                  ),
                  _buildFilterChip(
                    'Normal',
                    'normal',
                    _priority == 'normal',
                    'priority',
                  ),
                  _buildFilterChip(
                    'High',
                    'high',
                    _priority == 'high',
                    'priority',
                  ),
                  _buildFilterChip(
                    'Urgent',
                    'urgent',
                    _priority == 'urgent',
                    'priority',
                  ),
                ],
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem(
          enabled: false,
          child: Row(
            children: [
              Checkbox(
                value: _showArchived,
                onChanged: (value) {
                  _triggerHaptic();
                  setState(() {
                    _showArchived = value!;
                  });
                  widget.onFiltersChanged(
                    _messageType,
                    _status,
                    _priority,
                    _showArchived,
                  );
                },
                activeColor: AppColors.edgePrimary,
              ),
              const Text(
                'Show Archived',
                style: TextStyle(fontSize: 13, color: AppColors.edgeText),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.clear_all, color: AppColors.edgeError, size: 18),
              SizedBox(width: 8),
              Text(
                'Clear All Filters',
                style: TextStyle(color: AppColors.edgeError, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.edgePrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.edgePrimary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_list,
              color: AppColors.edgePrimary,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Filters',
              style: TextStyle(
                color: AppColors.edgePrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (_activeFilterCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.edgePrimary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    '$_activeFilterCount',
                    style: const TextStyle(
                      color: AppColors.edgeSurface,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? value,
    bool isSelected,
    String category,
  ) {
    return GestureDetector(
      onTap: () {
        _triggerHaptic();
        setState(() {
          switch (category) {
            case 'type':
              _messageType = value;
              break;
            case 'status':
              _status = value;
              break;
            case 'priority':
              _priority = value;
              break;
          }
        });
        widget.onFiltersChanged(
          _messageType,
          _status,
          _priority,
          _showArchived,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.edgePrimary : AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.edgePrimary : AppColors.edgeDivider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? AppColors.edgeSurface
                : AppColors.edgeTextSecondary,
          ),
        ),
      ),
    );
  }
}

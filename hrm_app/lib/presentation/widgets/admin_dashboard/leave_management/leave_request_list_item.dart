import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/leave_request_model.dart';
import 'package:hrm_app/presentation/widgets/admin_dashboard/leave_management/leave_request_detail_dialog.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveRequestListItem extends StatelessWidget {
  final LeaveRequestModel leaveRequest;
  final Function(String status, String? comments) onStatusUpdate;

  const LeaveRequestListItem({
    super.key,
    required this.leaveRequest,
    required this.onStatusUpdate,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallDevice = MediaQuery.of(context).size.width < 360;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor().withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _triggerHaptic();
            _showDetailDialog(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isSmallDevice ? 18 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor().withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  leaveRequest.employeeName,
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 18 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.edgeText,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStatusChip(),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.edgePrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.badge_rounded,
                                  size: 16,
                                  color: AppColors.edgePrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  leaveRequest.employeeIdNumber,
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 13 : 14,
                                    color: AppColors.edgeTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.edgeAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.work_rounded,
                                  size: 16,
                                  color: AppColors.edgeAccent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  leaveRequest.employeeJobTitle,
                                  style: TextStyle(
                                    fontSize: isSmallDevice ? 13 : 14,
                                    color: AppColors.edgeTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.edgeSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.edgeDivider, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.edgeText.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: _getLeaveTypeIcon(),
                              label: 'Leave Type',
                              value: leaveRequest.leaveTypeDisplayName,
                              isSmallDevice: isSmallDevice,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.access_time_rounded,
                              label: 'Duration',
                              value: leaveRequest.durationText,
                              isSmallDevice: isSmallDevice,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date Range',
                              value: leaveRequest.dateRangeText,
                              isSmallDevice: isSmallDevice,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.schedule_rounded,
                              label: 'Submitted',
                              value: leaveRequest.timeAgo,
                              isSmallDevice: isSmallDevice,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (leaveRequest.isEmergency) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.edgeError,
                          AppColors.edgeError.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgeError.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.priority_high_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Emergency Request',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (leaveRequest.reason.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.edgeSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.edgeDivider,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgeText.withOpacity(0.03),
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
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.edgePrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.message_rounded,
                                size: 16,
                                color: AppColors.edgePrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Reason',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.edgeText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          leaveRequest.reason,
                          style: TextStyle(
                            fontSize: isSmallDevice ? 14 : 15,
                            color: AppColors.edgeText,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                if (leaveRequest.status != 'pending' &&
                    leaveRequest.approverInfo != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor().withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getStatusColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            leaveRequest.status == 'approved'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: _getStatusColor(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            leaveRequest.approverInfo!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(),
                            ),
                          ),
                        ),
                        if (leaveRequest.approvalTimestamp != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            _formatApprovalTime(
                              leaveRequest.approvalTimestamp!,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.edgeTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (leaveRequest.status == 'pending') ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.edgeSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.edgeDivider,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.edgeText.withOpacity(0.03),
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
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.edgePrimary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.touch_app_rounded,
                                size: 16,
                                color: AppColors.edgePrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.edgeText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildActionButtons(context),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallDevice,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: AppColors.edgePrimary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallDevice ? 11 : 12,
                color: AppColors.edgeTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallDevice ? 13 : 14,
            color: AppColors.edgeText,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_getStatusColor(), _getStatusColor().withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        leaveRequest.statusDisplayName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.check_rounded,
            color: AppColors.edgeAccent,
            label: 'Approve',
            onPressed: () => _showStatusUpdateDialog(context, 'approved'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            icon: Icons.close_rounded,
            color: AppColors.edgeError,
            label: 'Reject',
            onPressed: () => _showStatusUpdateDialog(context, 'rejected'),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _triggerHaptic();
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (leaveRequest.status.toLowerCase()) {
      case 'pending':
        return AppColors.edgeWarning;
      case 'approved':
        return AppColors.edgeAccent;
      case 'rejected':
        return AppColors.edgeError;
      case 'on_hold':
        return AppColors.edgePrimary;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  IconData _getLeaveTypeIcon() {
    switch (leaveRequest.leaveType.toLowerCase()) {
      case 'sick':
        return Icons.health_and_safety_rounded;
      case 'vacation':
        return Icons.beach_access_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'maternity':
        return Icons.child_care_rounded;
      case 'paternity':
        return Icons.family_restroom_rounded;
      case 'bereavement':
        return Icons.favorite_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'casual':
        return Icons.event_rounded;
      case 'work_from_home':
        return Icons.home_rounded;
      case 'permission':
        return Icons.access_time_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => LeaveRequestDetailDialog(
        leaveRequest: leaveRequest,
        onStatusUpdate: onStatusUpdate,
      ),
    );
  }

  String _getButtonText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approve';
      case 'rejected':
        return 'Reject';
      case 'on_hold':
        return 'Hold';
      default:
        return status.toUpperCase();
    }
  }

  String _formatApprovalTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showStatusUpdateDialog(BuildContext context, String status) {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = AppColors.edgeAccent;
        statusIcon = Icons.check_circle_rounded;
        statusMessage = 'Are you sure you want to approve this leave request?';
        break;
      case 'rejected':
        statusColor = AppColors.edgeError;
        statusIcon = Icons.cancel_rounded;
        statusMessage = 'Are you sure you want to reject this leave request?';
        break;
      case 'on_hold':
        statusColor = AppColors.edgeWarning;
        statusIcon = Icons.pause_circle_rounded;
        statusMessage =
            'Are you sure you want to put this leave request on hold?';
        break;
      default:
        statusColor = AppColors.edgeTextSecondary;
        statusIcon = Icons.help_rounded;
        statusMessage = 'Are you sure you want to update this leave request?';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${status.toUpperCase()} Leave Request',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.edgeText,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.edgeDivider, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Employee: ${leaveRequest.employeeName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.edgeText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 16,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Leave Type: ${leaveRequest.leaveTypeDisplayName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.edgeText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duration: ${leaveRequest.durationText}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.edgeText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.edgeTextSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Date Range: ${leaveRequest.dateRangeText}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.edgeText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                statusMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.edgeText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.edgeTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onStatusUpdate(status, null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              _getButtonText(status),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

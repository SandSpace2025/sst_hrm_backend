import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrm_app/data/models/leave_request_model.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveRequestDetailDialog extends StatelessWidget {
  final LeaveRequestModel leaveRequest;
  final Function(String status, String? comments) onStatusUpdate;

  const LeaveRequestDetailDialog({
    super.key,
    required this.leaveRequest,
    required this.onStatusUpdate,
  });

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AppColors.edgeSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.edgeDivider.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.edgeText.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.edgePrimary,
                    AppColors.edgePrimary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leave Request Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ID: ${leaveRequest.id.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {
                        _triggerHaptic();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: 'Employee Information',
                      icon: Icons.person_rounded,
                      children: [
                        _buildInfoRow('Name', leaveRequest.employeeName),
                        _buildInfoRow(
                          'Employee ID',
                          leaveRequest.employeeIdNumber,
                        ),
                        _buildInfoRow('Email', leaveRequest.employeeEmail),
                        _buildInfoRow(
                          'Job Title',
                          leaveRequest.employeeJobTitle,
                        ),
                        if (leaveRequest.employeePhone.isNotEmpty)
                          _buildInfoRow('Phone', leaveRequest.employeePhone),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSection(
                      title: 'Leave Details',
                      icon: Icons.event_rounded,
                      children: [
                        _buildInfoRow(
                          'Leave Type',
                          leaveRequest.leaveTypeDisplayName,
                        ),
                        _buildInfoRow(
                          'Start Date',
                          _formatDate(leaveRequest.startDate),
                        ),
                        _buildInfoRow(
                          'End Date',
                          _formatDate(leaveRequest.endDate),
                        ),
                        _buildInfoRow('Duration', leaveRequest.durationText),
                        _buildInfoRow('Status', leaveRequest.statusDisplayName),
                        if (leaveRequest.isEmergency)
                          _buildInfoRow(
                            'Priority',
                            'Emergency',
                            valueColor: AppColors.edgeError,
                          ),
                        if (leaveRequest.isHalfDay)
                          _buildInfoRow(
                            'Half Day',
                            leaveRequest.halfDayType == 'first_half'
                                ? 'First Half'
                                : 'Second Half',
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSection(
                      title: 'Reason',
                      icon: Icons.description_rounded,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.edgePrimary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.edgePrimary.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            leaveRequest.reason,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.edgeText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (leaveRequest.adminComments.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Admin Comments',
                        icon: Icons.comment_rounded,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.edgeAccent.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.edgeAccent.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              leaveRequest.adminComments,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.edgeText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (leaveRequest.reviewedAt != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Review Information',
                        icon: Icons.verified_rounded,
                        children: [
                          _buildInfoRow(
                            'Reviewed By',
                            leaveRequest.reviewedByName ?? 'Unknown',
                          ),
                          _buildInfoRow(
                            'Review Date',
                            _formatDate(leaveRequest.reviewedAt!),
                          ),
                          if (leaveRequest.reviewedByDesignation != null)
                            _buildInfoRow(
                              'Designation',
                              leaveRequest.reviewedByDesignation!,
                            ),
                        ],
                      ),
                    ],

                    if (leaveRequest.attachments.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'Attachments',
                        icon: Icons.attach_file_rounded,
                        children: [
                          ...leaveRequest.attachments.map(
                            (attachment) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.edgeSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.edgeDivider,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.edgePrimary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.attach_file_rounded,
                                      color: AppColors.edgePrimary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attachment.originalName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.edgeText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Uploaded: ${_formatDate(attachment.uploadedAt)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.edgeTextSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (leaveRequest.status == 'pending') ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.edgeDivider.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        status: 'approved',
                        icon: Icons.check_rounded,
                        label: 'Approve',
                        color: AppColors.edgeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        status: 'rejected',
                        icon: Icons.close_rounded,
                        label: 'Reject',
                        color: AppColors.edgeError,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String status,
    required IconData icon,
    required String label,
    required Color color,
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
            _showStatusUpdateDialog(context, status);
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
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
              child: Icon(icon, size: 16, color: AppColors.edgePrimary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.edgeText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeTextSecondary,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: AppColors.edgeTextSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.edgeText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showStatusUpdateDialog(BuildContext context, String status) {
    Navigator.of(context).pop();

    final TextEditingController commentsController = TextEditingController();
    final statusColor = _getStatusColor(status);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.edgeSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.edgeDivider.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.edgeText.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${status.toUpperCase()} Leave Request',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.edgeText,
                          ),
                        ),
                        Text(
                          'Employee: ${leaveRequest.employeeName}',
                          style: const TextStyle(
                            fontSize: 13,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Leave Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type: ${leaveRequest.leaveTypeDisplayName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                      ),
                    ),
                    Text(
                      'Duration: ${leaveRequest.durationText}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentsController,
                style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
                decoration: InputDecoration(
                  labelText: 'Comments (Optional)',
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.edgeTextSecondary,
                  ),
                  hintText: 'Add any additional comments...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.edgeTextSecondary.withOpacity(0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.comment_rounded,
                    color: AppColors.edgeTextSecondary,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.edgeDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.edgeDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.edgePrimary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.edgeTextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [statusColor, statusColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
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
                            Navigator.of(context).pop();
                            onStatusUpdate(
                              status,
                              commentsController.text.trim().isEmpty
                                  ? null
                                  : commentsController.text.trim(),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          splashColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.edgeAccent;
      case 'rejected':
        return AppColors.edgeError;
      case 'on_hold':
        return AppColors.edgeWarning;
      default:
        return AppColors.edgePrimary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_rounded;
      case 'rejected':
        return Icons.close_rounded;
      case 'on_hold':
        return Icons.pause_rounded;
      default:
        return Icons.help_rounded;
    }
  }
}

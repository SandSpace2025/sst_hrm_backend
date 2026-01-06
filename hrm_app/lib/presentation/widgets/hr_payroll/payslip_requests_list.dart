import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/screens/hr/hr_payroll_management_screen.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayslipRequestsList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final Function(
    String requestId,
    String status,
    String? payslipUrl,
    String? rejectionReason,
  )
  onStatusUpdate;

  const PayslipRequestsList({
    super.key,
    required this.requests,
    required this.isLoading,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
        ),
      );
    }

    final activeRequests = requests.where((request) {
      final status = (request['status'] ?? 'pending')
          .toString()
          .toLowerCase()
          .trim();

      if (status == 'approved' ||
          status == 'rejected' ||
          status == 'completed') {
        return false;
      }

      return status == 'pending' ||
          status == 'processing' ||
          status == 'on-hold' ||
          status == 'on_hold';
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.edgePrimary,
      child: activeRequests.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.edgePrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.request_page_outlined,
                          size: 48,
                          color: AppColors.edgePrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No Active Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All requests have been processed.\nCompleted requests can be found in the Approval History tab.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeRequests.length,
              itemBuilder: (context, index) {
                final request = activeRequests[index];
                return _buildRequestCard(context, request);
              },
            ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    final status = request['status'] ?? 'pending';
    final employee = request['employee'] ?? {};
    final employeeName = employee['name'] ?? 'Unknown Employee';
    final employeeId = employee['employeeId'] ?? 'N/A';
    final createdAt = request['createdAt'] ?? '';
    final processedBy = request['processedBy'] ?? {};
    final processedAt = request['processedAt'] ?? '';
    final payslipUrl = request['payslipUrl'] ?? '';
    final rejectionReason = request['rejectionReason'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.edgeDivider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.edgeText,
                        ),
                      ),
                      Text(
                        'ID: $employeeId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.edgeTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusLabel(status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildDetailItem(
              'Payslip For',
              '${request['startMonth'] ?? 'N/A'} ${request['startYear'] ?? ''}',
              Icons.calendar_month,
            ),

            const SizedBox(height: 12),

            _buildDetailItem(
              'Requested Date',
              _formatDate(createdAt),
              Icons.schedule,
            ),

            if ((status == 'completed' || status == 'approved') &&
                payslipUrl.isNotEmpty &&
                (request['payslipExpiry'] == null ||
                    DateTime.tryParse(
                          request['payslipExpiry'],
                        )?.isAfter(DateTime.now()) ==
                        true)) ...[
              const SizedBox(height: 12),
              _buildDetailItem('Payslip URL', payslipUrl, Icons.link),
            ],

            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                'Rejection Reason',
                rejectionReason,
                Icons.cancel,
                textColor: AppColors.edgeError,
              ),
            ],

            if (processedBy.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                'Processed By',
                processedBy['name'] ?? 'Unknown',
                Icons.person,
              ),
            ],

            if (processedAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem(
                'Processed Date',
                _formatDate(processedAt),
                Icons.check_circle,
              ),
            ],

            if (status == 'pending' ||
                status == 'processing' ||
                status == 'on-hold' ||
                status == 'on_hold') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            HRPayrollManagementScreen(payslipRequest: request),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet, size: 18),
                  label: const Text('Process Payslip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.edgePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showStatusUpdateDialog(
                        context,
                        request['_id'],
                        'rejected',
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.edgeError,
                        side: const BorderSide(color: AppColors.edgeError),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    IconData icon, {
    Color? textColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.edgeTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.edgeTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor ?? AppColors.edgeText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.edgeWarning;
      case 'processing':
        return AppColors.edgePrimary;
      case 'completed':
        return AppColors.edgeAccent;
      case 'rejected':
        return AppColors.edgeError;
      case 'on-hold':
        return AppColors.edgeWarning;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.hourglass_empty;
      case 'completed':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'on-hold':
        return Icons.pause_circle;
      default:
        return Icons.help;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Processing';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Ready';
      case 'rejected':
        return 'Rejected';
      case 'on-hold':
      case 'on_hold':
        return 'Hold';
      default:
        return status;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  void _showStatusUpdateDialog(
    BuildContext context,
    String requestId,
    String status,
  ) {
    final TextEditingController payslipUrlController = TextEditingController();
    final TextEditingController rejectionReasonController =
        TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 20,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.edgeSurface,
                  AppColors.edgeSurface.withOpacity(0.95),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(status).withOpacity(0.1),
                        _getStatusColor(status).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getStatusColor(status).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        _getStatusTitle(status),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.edgeText,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      Text(
                        _getStatusSubtitle(status),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeTextSecondary,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (status == 'completed') ...[
                        _buildInputField(
                          controller: payslipUrlController,
                          label: 'Payslip URL',
                          hint: 'Enter the payslip download URL (optional)',
                          icon: Icons.link,
                          isOptional: true,
                        ),
                      ],
                      if (status == 'rejected') ...[
                        _buildInputField(
                          controller: rejectionReasonController,
                          label: 'Rejection Reason',
                          hint: 'Please provide a reason for rejection',
                          icon: Icons.note_alt,
                          maxLines: 3,
                          isRequired: true,
                        ),
                      ],
                      if (status == 'processing') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.edgeWarning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.edgeWarning.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.edgeWarning,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This will mark the request as being processed. You can complete or reject it later.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.edgeWarning,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.edgeTextSecondary,
                            side: const BorderSide(
                              color: AppColors.edgeDivider,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onStatusUpdate(
                              requestId,
                              status,
                              payslipUrlController.text.trim().isNotEmpty
                                  ? payslipUrlController.text.trim()
                                  : null,
                              rejectionReasonController.text.trim().isNotEmpty
                                  ? rejectionReasonController.text.trim()
                                  : null,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getStatusColor(status),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _getActionButtonText(status),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool isRequired = false,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.edgeTextSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.edgeText,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.edgeError,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (isOptional) ...[
              const SizedBox(width: 4),
              const Text(
                '(Optional)',
                style: TextStyle(
                  color: AppColors.edgeTextSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.edgeTextSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.edgeBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.edgeDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.edgePrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.edgeText),
        ),
      ],
    );
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'processing':
        return 'Start Processing';
      case 'completed':
        return 'Complete Request';
      case 'rejected':
        return 'Reject Request';
      default:
        return 'Update Status';
    }
  }

  String _getStatusSubtitle(String status) {
    switch (status) {
      case 'processing':
        return 'Mark this payslip request as being processed';
      case 'completed':
        return 'Mark this payslip request as completed';
      case 'rejected':
        return 'Reject this payslip request with a reason';
      default:
        return 'Update the status of this request';
    }
  }

  String _getActionButtonText(String status) {
    switch (status) {
      case 'processing':
        return 'Start Processing';
      case 'completed':
        return 'Complete';
      case 'rejected':
        return 'Reject';
      default:
        return 'Update';
    }
  }
}

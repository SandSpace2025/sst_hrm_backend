import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayslipHistoryCard extends StatelessWidget {
  final Map<String, dynamic> payslip;
  final VoidCallback? onDownloadTap;

  const PayslipHistoryCard({
    super.key,
    required this.payslip,
    this.onDownloadTap,
  });

  @override
  Widget build(BuildContext context) {
    final month = payslip['month'] ?? 'Unknown';
    final year = payslip['year'] ?? 'Unknown';
    final status = payslip['status'] ?? 'pending';
    final netSalary = payslip['netSalary'] ?? 0.0;
    final requestDate = payslip['requestDate'] != null
        ? DateTime.parse(payslip['requestDate'])
        : DateTime.now();
    final expiry = payslip['payslipExpiry'];
    final isDownloadAvailable =
        payslip['payslipUrl'] != null &&
        (expiry == null ||
            DateTime.tryParse(expiry)?.isAfter(DateTime.now()) == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgePrimary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$month $year',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    Text(
                      'Requested on ${_formatDate(requestDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Net Salary',
                  '₹${_formatAmount(netSalary)}',
                  AppColors.edgeAccent,
                ),
              ),
              if (isDownloadAvailable) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: ElevatedButton.icon(
                    onPressed: onDownloadTap,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.edgePrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (payslip['reason'] != null && payslip['reason'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.edgePrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_outlined,
                    color: AppColors.edgePrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${payslip['reason']}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = AppColors.edgeAccent.withOpacity(0.1);
        textColor = AppColors.edgeAccent;
        statusText = 'Ready';
        break;
      case 'pending':
        backgroundColor = AppColors.edgePrimary.withOpacity(0.1);
        textColor = AppColors.edgePrimary;
        statusText = 'Processing';
        break;
      case 'rejected':
        backgroundColor = AppColors.edgeError.withOpacity(0.1);
        textColor = AppColors.edgeError;
        statusText = 'Rejected';
        break;
      case 'on-hold':
      case 'on_hold':
        backgroundColor = AppColors.edgeWarning.withOpacity(0.1);
        textColor = AppColors.edgeWarning;
        statusText = 'Hold';
        break;
      default:
        backgroundColor = AppColors.edgeTextSecondary.withOpacity(0.1);
        textColor = AppColors.edgeTextSecondary;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.edgeTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.edgeAccent;
      case 'pending':
        return AppColors.edgePrimary;
      case 'rejected':
        return AppColors.edgeError;
      case 'on-hold':
      case 'on_hold':
        return AppColors.edgeWarning;
      default:
        return AppColors.edgeTextSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'on-hold':
      case 'on_hold':
        return Icons.pause_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

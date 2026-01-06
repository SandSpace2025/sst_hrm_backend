import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class LeaveRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onActionTap;

  const LeaveRequestCard({super.key, required this.request, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final leaveType = request['leaveType'] ?? 'Unknown';
    final startDate = request['startDate'];
    final endDate = request['endDate'];
    final reason = request['reason'] ?? '';
    final status = request['status'] ?? 'pending';
    final submittedDate = request['submittedDate'];
    final durationType = request['durationType'] ?? 'full_day';
    final days = _calculateDuration(startDate, endDate, durationType);
    final isPending = status.toString().toLowerCase() == 'pending';

    Color statusColor;
    Color statusBgColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981); // Green
        statusBgColor = const Color(0xFFD1FAE5);
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444); // Red
        statusBgColor = const Color(0xFFFEE2E2);
        statusText = 'Declined';
        break;
      case 'cancelled':
        statusColor = const Color(0xFF6B7280); // Grey
        statusBgColor = const Color(0xFFF3F4F6);
        statusText = 'Cancelled';
        break;
      default:
        statusColor = const Color(0xFFF97316); // Orange-ish for pending
        statusBgColor = const Color(0xFFFFEDD5);
        statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: const GradientRotation(0.95), // ~20 degrees
          colors: [Color(0xFF00B359), Color.fromARGB(0, 231, 230, 230)],
          stops: [0.0, 0.9],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5), // Border width
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.5), // Inner radius
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPending)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onActionTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _formatLeaveType(leaveType),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Requesting leave for $days',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateRange(startDate, endDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: 'Submitted on ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  children: [
                    TextSpan(
                      text: _formatDate(submittedDate),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    text: 'Reason for leave: ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    children: [
                      TextSpan(
                        text: reason,
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLeaveType(String type) {
    return type
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  String _calculateDuration(String? start, String? end, String durationType) {
    if (start == null) return '0 Days';
    if (durationType == 'hours') return 'Hours'; // Simplify for now
    if (durationType == 'half_day') return '0.5 Days';

    try {
      final s = DateTime.parse(start);
      final e = end != null ? DateTime.parse(end) : s;
      final diff = e.difference(s).inDays + 1;
      return '$diff Days';
    } catch (_) {
      return '1 Days';
    }
  }

  String _formatDateRange(String? start, String? end) {
    if (start == null) return '';
    try {
      final s = DateTime.parse(start);
      final e = end != null ? DateTime.parse(end) : s;
      final fmt = DateFormat('dd-MM-yyyy');
      if (s.isAtSameMomentAs(e)) {
        return fmt.format(s);
      }
      return '${fmt.format(s)} to ${fmt.format(e)}';
    } catch (_) {
      return start ?? '';
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd-MM-yy').format(d);
    } catch (_) {
      return date ?? '';
    }
  }
}

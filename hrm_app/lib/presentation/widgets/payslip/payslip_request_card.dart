import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class PayslipRequestCard extends StatelessWidget {
  final VoidCallback? onRequestTap;
  final DateTime? selectedDate;
  final VoidCallback? onDateSelect;

  const PayslipRequestCard({
    super.key,
    this.onRequestTap,
    this.selectedDate,
    this.onDateSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.edgeAccent.withOpacity(0.1),
            AppColors.edgePrimary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.edgeAccent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.edgeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.request_page,
                  color: AppColors.edgeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Payslip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onDateSelect,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedDate != null
                                ? '${_getMonthName(selectedDate!.month)} ${selectedDate!.year}'
                                : 'Select Month',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.edgePrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.edgePrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Click the button below to request your payslip for the current month. HR will be notified and will process your request.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.edgeTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRequestTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Request Current Month Payslip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.edgeAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.edgeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.edgeAccent.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule, color: AppColors.edgeAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HR will be notified immediately and process within 2-3 business days',
                    style: TextStyle(
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
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

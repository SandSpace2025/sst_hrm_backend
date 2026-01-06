import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class LeaveBalanceCircles extends StatelessWidget {
  const LeaveBalanceCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final statistics = employeeProvider.leaveStatistics;
        final leaveBalance = employeeProvider.leaveBalance;

        // Extract values or default to 0
        final available =
            leaveBalance?['leaveBalance']?['casualLeave'] ??
            6; // Mocking 6 if null for now, or 0. Logic might need adjustment based on backend.
        final requested = statistics?['pendingLeaves'] ?? 0;
        final approved = statistics?['approvedLeaves'] ?? 0;
        final declined =
            statistics?['rejectedLeaves'] ??
            0; // Assuming 'rejectedLeaves' key exists, else 0

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Leaves',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircle(
                    'Available',
                    available.toString(),
                    AppColors.primary,
                  ),
                  _buildCircle(
                    'Requested',
                    requested.toString(),
                    const Color(0xFF00B359),
                  ), // Using green-ish for consistency or primary
                  _buildCircle(
                    'Approved',
                    approved.toString(),
                    AppColors.success,
                  ),
                  _buildCircle(
                    'Declined',
                    declined.toString(),
                    AppColors.success,
                  ), // Image shows green circles for all numbers
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircle(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white, // Highlight
                Color(0xFFE2F6F0), // Shadow/Depth
              ],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBbf7d0), // Stronger green for definition
                offset: const Offset(3, 3), // Tight, directional offset
                blurRadius: 0, // Hard edge, no glow
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

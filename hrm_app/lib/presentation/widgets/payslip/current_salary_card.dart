import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';

class CurrentSalaryCard extends StatelessWidget {
  const CurrentSalaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        final employee = employeeProvider.employeeProfile;
        final currentSalary = employeeProvider.currentSalary;
        final hasData =
            currentSalary != null && currentSalary['hasData'] == true;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF5), // Light Mint Background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFBCEBD4), // Slightly darker mint border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBCEBD4).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Section
                  Text(
                    employee?.name ?? 'Employee',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w400, // Regular/Light similar to design
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF424242),
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee?.jobTitle ?? 'Designation',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9E9E9E), // Grey text
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Salary Details
                  if (hasData) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Monthly Salary (Left)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total monthly salary',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF616161),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'INR ${_formatCurrency(currentSalary['netSalary'])}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600, // SemiBold
                                  color: Color(0xFF00C853), // Bright Green
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Center(
                      child: Text(
                        'Salary details pending',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Footer Company Name
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Sandspace Technologies Pvt Ltd',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA5D6A7), // Light Green text
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final numAmount = amount is num
        ? amount
        : double.tryParse(amount.toString()) ?? 0;
    return numAmount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

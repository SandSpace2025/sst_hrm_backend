import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hrm_app/presentation/providers/employee_provider.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Consumer<EmployeeProvider>(
      builder: (context, employeeProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: employeeProvider.isApplyingLeave ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.edgeAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.edgeTextSecondary.withOpacity(
                0.3,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: employeeProvider.isApplyingLeave
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit Leave Request',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
          ),
        );
      },
    );
  }
}

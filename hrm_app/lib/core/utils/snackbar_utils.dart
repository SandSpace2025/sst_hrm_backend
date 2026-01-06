import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class SnackBarUtils {
  SnackBarUtils._();

  static void showSuccess(BuildContext context, String message) {
    _showStyledSnackBar(
      context,
      message,
      AppColors.success,
      Icons.check_circle_rounded,
    );
  }

  static void showError(BuildContext context, String message) {
    _showStyledSnackBar(context, message, AppColors.error, Icons.error_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _showStyledSnackBar(
      context,
      message,
      AppColors.primary,
      Icons.info_rounded,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showStyledSnackBar(
      context,
      message,
      AppColors.warning,
      Icons.warning_rounded,
    );
  }

  static void _showStyledSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Deprecated: Prefer using specific context-based methods for consistent UI
  // But for now keeping them as wrappers if context is needed, or just redirecting
  // fluttertoast usages in valid contexts to the above methods.
}

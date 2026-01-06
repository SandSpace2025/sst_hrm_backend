import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class CustomErrorState extends StatelessWidget {
  final String message;
  final String? title;
  final bool isSmallDevice;
  final VoidCallback? onRetry;

  const CustomErrorState({
    super.key,
    required this.message,
    this.title = 'Error',
    this.isSmallDevice = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmallDevice ? 20 : 24),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeError.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isSmallDevice ? 20 : 24,
            height: isSmallDevice ? 20 : 24,
            decoration: BoxDecoration(
              color: AppColors.edgeError.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.edgeError,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: isSmallDevice ? 14 : 15,
                    color: AppColors.edgeError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: isSmallDevice ? 12 : 13,
                    color: AppColors.edgeTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.refresh,
                color: AppColors.edgeTextSecondary,
              ),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

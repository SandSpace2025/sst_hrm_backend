import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class CustomLoadingState extends StatelessWidget {
  final String message;
  final bool isSmallDevice;

  const CustomLoadingState({
    super.key,
    this.message = 'Loading...',
    this.isSmallDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmallDevice ? 20 : 24),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallDevice ? 20 : 24,
            height: isSmallDevice ? 20 : 24,
            decoration: BoxDecoration(
              color: AppColors.edgePrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.edgePrimary),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isSmallDevice ? 14 : 15,
                color: AppColors.edgeText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

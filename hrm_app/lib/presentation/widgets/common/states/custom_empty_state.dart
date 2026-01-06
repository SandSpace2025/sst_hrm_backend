import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class CustomEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSmallDevice;

  const CustomEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isSmallDevice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmallDevice ? 24 : 28),
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.edgeDivider.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isSmallDevice ? 48 : 56,
            height: isSmallDevice ? 48 : 56,
            decoration: BoxDecoration(
              color: AppColors.edgeTextSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: isSmallDevice ? 24 : 28,
              color: AppColors.edgeTextSecondary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallDevice ? 14 : 15,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isSmallDevice ? 12 : 13,
              color: AppColors.edgeTextSecondary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

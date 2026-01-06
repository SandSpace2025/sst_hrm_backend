import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class MinimalHeader extends StatelessWidget {
  final String title;

  const MinimalHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(bottom: BorderSide(color: AppColors.edgeDivider)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dashboard_outlined,
            color: AppColors.edgePrimary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.edgeText,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

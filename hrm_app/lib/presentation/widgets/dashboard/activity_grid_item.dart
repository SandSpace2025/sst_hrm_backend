import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class ActivityGridItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? value;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final Color? customColor;

  const ActivityGridItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.value,
    this.icon,
    this.onTap,
    this.isHighlighted = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    // Uniform light green background for all cards as per reference
    final backgroundColor = AppColors.primary.withValues(alpha: 0.05);

    final cardContent = Container(
      clipBehavior: Clip.antiAlias, // Clip the watermark icon
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Watermark Icon (Bottom Right)
          if (icon != null)
            Positioned(
              right: -10,
              bottom: -10,
              child: SizedBox(
                width: 100, // Large size for watermark effect
                height: 100,
                child: icon,
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary, // Dark text
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (value != null)
                  Text(
                    value!,
                    style: const TextStyle(
                      fontSize: 48, // Large value
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary, // Green color for value
                      height: 1.0,
                    ),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );

    // Only wrap in GestureDetector if onTap is provided
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: cardContent);
    }

    return cardContent;
  }
}

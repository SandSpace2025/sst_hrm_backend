import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class DashboardHeader extends StatelessWidget {
  final String title;
  final String userName;
  final String userRole;
  final VoidCallback onMenuTap;
  final Animation<double>? menuAnimation;
  final bool showMenuButton;

  const DashboardHeader({
    super.key,
    required this.title,
    required this.userName,
    required this.userRole,
    required this.onMenuTap,
    this.menuAnimation,
    this.showMenuButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.edgeSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.edgeDivider.withOpacity(0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.edgeText.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              if (showMenuButton) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMenuTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.edgePrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.edgePrimary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: menuAnimation != null
                          ? AnimatedIcon(
                              icon: AnimatedIcons.menu_close,
                              progress: menuAnimation!,
                              color: AppColors.edgePrimary,
                              size: 20,
                            )
                          : const Icon(
                              Icons.menu_rounded,
                              color: AppColors.edgePrimary,
                              size: 20,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.edgeText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome back, $userName',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.edgeTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.edgePrimary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  userRole,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.edgePrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

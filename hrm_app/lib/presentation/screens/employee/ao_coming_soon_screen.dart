import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_colors.dart';

class AOComingSoonScreen extends StatelessWidget {
  const AOComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.edgeBackground,
      appBar: AppBar(
        title: const Text(
          'EOD Report (AO)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.edgePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.edgePrimary.withValues(alpha: 26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.watch_later_outlined,
                  color: AppColors.edgePrimary,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'EOD Form Coming Soon',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.edgeText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'We\'re working on a specialized EOD form for Academic Overseas employees. This feature will be available soon.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.edgeTextSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.edgeSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.edgeDivider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 12.7),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What to expect:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.edgeText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      'Simplified reporting process',
                      Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      'Organization-specific fields',
                      Icons.business_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      'Mobile-optimized interface',
                      Icons.phone_android_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      'Real-time submission tracking',
                      Icons.track_changes_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.edgeWarning.withValues(alpha: 26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.edgeWarning.withValues(alpha: 76),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.edgeWarning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'For immediate EOD reporting needs, please contact your HR representative.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.edgeWarning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildFeatureItem(String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.edgeAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.edgeText,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

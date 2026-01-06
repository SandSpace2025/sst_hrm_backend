import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';

class EmployeeDashboardSkeleton extends StatelessWidget {
  const EmployeeDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Shimmer
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading.rectangular(height: 16, width: 100),
                  SizedBox(height: 8),
                  ShimmerLoading.rectangular(height: 24, width: 180),
                ],
              ),
              ShimmerLoading.circular(width: 48),
            ],
          ),
          const SizedBox(height: 32),

          // 2. Attendance Section Shimmer
          const ShimmerLoading.rectangular(height: 180, width: double.infinity),
          const SizedBox(height: 32),

          // 3. Activity Grid Shimmer
          const ShimmerLoading.rectangular(
            height: 24,
            width: 150,
          ), // Section Title
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: List.generate(
              4,
              (index) => const ShimmerLoading.rectangular(
                height: 100,
                width: double.infinity, // Fixed: Added width
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 4. Announcements Shimmer
          const ShimmerLoading.rectangular(
            height: 24,
            width: 150,
          ), // Section Title
          const SizedBox(height: 16),
          Column(
            children: List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: ShimmerLoading.rectangular(
                  height: 100,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

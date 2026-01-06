import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';

class HRDashboardSkeleton extends StatelessWidget {
  const HRDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards Shimmer
            const Row(
              children: [
                Expanded(
                  child: ShimmerLoading.rectangular(
                    height: 140,
                    width: double.infinity,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ShimmerLoading.rectangular(
                    height: 140,
                    width: double.infinity,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: ShimmerLoading.rectangular(
                    height: 100,
                    width: double.infinity,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ShimmerLoading.rectangular(
                    height: 100,
                    width: double.infinity,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Section Title Shimmer
            const ShimmerLoading.rectangular(height: 24, width: 150),
            const SizedBox(height: 16),

            // Recent Activity / Employees List Shimmer
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return ShimmerLoading.listItem(
                  margin: const EdgeInsets.only(bottom: 12),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

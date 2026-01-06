import 'package:flutter/material.dart';
import 'package:hrm_app/presentation/widgets/common/shimmer_loading.dart';

class AdminDashboardSkeleton extends StatelessWidget {
  const AdminDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards Shimmer (Admin often has more cards, e.g. 2x2 grid or row)
            // Assuming 2 cards per row for consistency with layout
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

            // Notifications / Activity Section Title
            const ShimmerLoading.rectangular(height: 24, width: 150),
            const SizedBox(height: 16),

            // Notifications List
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

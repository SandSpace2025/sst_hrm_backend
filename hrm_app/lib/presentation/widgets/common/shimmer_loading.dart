import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final ShimmerShape shape;
  final EdgeInsetsGeometry? margin;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.shape = ShimmerShape.rectangle,
    this.margin,
  });

  const ShimmerLoading.rectangular({
    super.key,
    required this.width,
    required this.height,
    this.margin,
  }) : shape = ShimmerShape.rectangle;

  const ShimmerLoading.circular({super.key, required this.width, this.margin})
    : height = 0,
      shape = ShimmerShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: width,
          height: shape == ShimmerShape.circle ? width : height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: shape == ShimmerShape.circle
                ? BorderRadius.circular(width / 2)
                : BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  
  static Widget listItem({double height = 80, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading.circular(width: 50),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading.rectangular(
                  width: double.infinity,
                  height: 16,
                  margin: EdgeInsets.only(bottom: 8),
                ),
                ShimmerLoading.rectangular(
                  width: double.infinity,
                  height: 14,
                  margin: EdgeInsets.only(bottom: 8),
                ),
                ShimmerLoading.rectangular(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  static Widget card({double height = 150, EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      child: ShimmerLoading.rectangular(width: double.infinity, height: height),
    );
  }
}

enum ShimmerShape { rectangle, circle }

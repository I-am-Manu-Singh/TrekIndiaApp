import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class GlassShimmer extends StatelessWidget {
  final Widget child;
  const GlassShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.black.withOpacity(0.05),
      highlightColor: Colors.black.withOpacity(0.01),
      child: child,
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;
  final BoxShape shape;

  const ShimmerBlock({
    super.key, 
    required this.width, 
    required this.height, 
    this.borderRadius = 12,
    this.margin,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        shape: shape,
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double height;
  final double borderRadius;
  const ShimmerCard({super.key, this.height = 100, this.borderRadius = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          ShimmerBlock(width: height - 32, height: height - 32, borderRadius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBlock(width: 150, height: 12),
                const SizedBox(height: 8),
                ShimmerBlock(width: double.infinity, height: 10, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

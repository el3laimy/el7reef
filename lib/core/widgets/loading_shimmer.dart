import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

/// تأثير Shimmer للتحميل
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 80,
    this.borderRadius = AppDimensions.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Shimmer لقائمة عناصر
  static Widget list({int count = 5, double itemHeight = 72}) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: LoadingShimmer(height: itemHeight),
        ),
      ),
    );
  }

  /// Shimmer لبطاقة بروفايل
  static Widget profileCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: AppColors.surface),
          const SizedBox(height: AppDimensions.md),
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
        ],
      ),
    );
  }
}

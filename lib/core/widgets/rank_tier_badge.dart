import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../constants/app_constants.dart';

/// بادج الرتبة البصرية (برونز → أسطوري)
class RankTierBadge extends StatelessWidget {
  final int rating;
  final double size;
  final bool showLabel;

  const RankTierBadge({
    super.key,
    required this.rating,
    this.size = 32,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final tier = _getTier(rating);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: tier.gradient,
            boxShadow: [
              BoxShadow(
                color: tier.color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              tier.icon,
              style: TextStyle(fontSize: size * 0.5),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            tier.label,
            style: AppTextStyles.labelMedium.copyWith(color: tier.color),
          ),
        ],
      ],
    );
  }

  static _RankTier _getTier(int rating) {
    if (rating > AppConstants.rankDiamondMax) {
      return _RankTier(
        label: 'أسطوري',
        icon: '🔥',
        color: AppColors.rankLegendary1,
        gradient: AppColors.legendaryGradient,
      );
    } else if (rating > AppConstants.rankPlatinumMax) {
      return _RankTier(
        label: 'ماسي',
        icon: '💠',
        color: AppColors.rankDiamond,
        gradient: const LinearGradient(
          colors: [Color(0xFF89CFF0), AppColors.rankDiamond],
        ),
      );
    } else if (rating > AppConstants.rankGoldMax) {
      return _RankTier(
        label: 'بلاتيني',
        icon: '💎',
        color: AppColors.rankPlatinum,
        gradient: const LinearGradient(
          colors: [Color(0xFF008B8B), AppColors.rankPlatinum],
        ),
      );
    } else if (rating > AppConstants.rankSilverMax) {
      return _RankTier(
        label: 'ذهبي',
        icon: '🥇',
        color: AppColors.rankGold,
        gradient: AppColors.goldGradient,
      );
    } else if (rating > AppConstants.rankBronzeMax) {
      return _RankTier(
        label: 'فضي',
        icon: '🥈',
        color: AppColors.rankSilver,
        gradient: const LinearGradient(
          colors: [Color(0xFF808080), AppColors.rankSilver],
        ),
      );
    } else {
      return _RankTier(
        label: 'برونزي',
        icon: '🥉',
        color: AppColors.rankBronze,
        gradient: const LinearGradient(
          colors: [Color(0xFF8B6914), AppColors.rankBronze],
        ),
      );
    }
  }
}

class _RankTier {
  final String label;
  final String icon;
  final Color color;
  final LinearGradient gradient;

  const _RankTier({
    required this.label,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

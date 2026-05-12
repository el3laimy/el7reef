import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../domain/entities/player.dart';
import '../controllers/team_roster_controller.dart';

class TeamRosterSearchResultTile extends StatelessWidget {
  final Player player;
  final TeamRosterController controller;

  const TeamRosterSearchResultTile({
    super.key,
    required this.player,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySurface,
            child: Text(
              player.name.isNotEmpty ? player.name[0] : '?',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: AppTextStyles.titleLarge),
                if (player.hasUsername)
                  Text(
                    player.displayUsername,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.isSubmitting.value
                ? null
                : () => controller.addRegisteredPlayer(player),
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

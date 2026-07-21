import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../domain/entities/match.dart';
import '../../../core/auth/auth_service.dart';

class HomeMyMatchCard extends StatelessWidget {
  final Match match;
  final int index;

  const HomeMyMatchCard({super.key, required this.match, required this.index});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final uid = authService.currentUserId ?? '';

    final bool isTeamA = match.teamAPlayerIds.contains(uid);
    final int? myScore = isTeamA ? match.scoreTeamA : match.scoreTeamB;
    final int? oppScore = isTeamA ? match.scoreTeamB : match.scoreTeamA;

    Color resultColor = AppColors.textMuted;
    String resultLabel = '—';
    if (myScore != null && oppScore != null) {
      if (myScore > oppScore) {
        resultColor = AppColors.success;
        resultLabel = 'فوز';
      } else if (myScore < oppScore) {
        resultColor = AppColors.error;
        resultLabel = 'خسارة';
      } else {
        resultColor = AppColors.secondary;
        resultLabel = 'تعادل';
      }
    }

    return El7reefGlassSurface(
          variant: El7reefGlassVariant.base,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm,
          ),
          radius: AppDimensions.radiusMd,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: resultColor.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    resultLabel == 'فوز'
                        ? '🏆'
                        : resultLabel == 'خسارة'
                        ? '😤'
                        : '🤝',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.status == MatchStatus.settled
                          ? 'مباراة منتهية'
                          : match.status == MatchStatus.live
                          ? 'مباراة جارية'
                          : 'قيد التسوية',
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      _formatDate(match.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (myScore != null)
                    Text(
                      '$myScore - $oppScore',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: resultColor,
                      ),
                    ),
                  Text(
                    resultLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: resultColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate(delay: (120 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'النهارده';
    if (diff.inDays == 1) return 'امبارح';
    return '${diff.inDays} يوم';
  }
}

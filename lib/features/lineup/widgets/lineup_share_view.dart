import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'bench_bar.dart';
import 'professional_pitch_card.dart';

class LineupShareView extends StatelessWidget {
  final String teamName;
  final String? opponentName;
  final String formationCode;
  final int playerCount;
  final List<FormationSlot> slots;
  final Map<String, LineupPlayer> playersByKey;
  final List<LineupPlayer> benchPlayers;
  final String? matchLabel;
  final VoidCallback? onShareText;

  const LineupShareView({
    super.key,
    required this.teamName,
    this.opponentName,
    required this.formationCode,
    required this.playerCount,
    required this.slots,
    required this.playersByKey,
    this.benchPlayers = const [],
    this.matchLabel,
    this.onShareText,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDeep,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamName,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                                  if ((opponentName ?? '').isNotEmpty)
                                    'ضد $opponentName',
                                  formationCode,
                                  matchLabel,
                                ]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(' • '),
                            style: AppTextStyles.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (onShareText != null)
                      IconButton(
                        onPressed: onShareText,
                        icon: const Icon(Icons.share_rounded),
                        tooltip: 'مشاركة',
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                ProfessionalPitchCard(
                  slots: slots,
                  playersByKey: playersByKey,
                  formationCode: formationCode,
                  playerCount: playerCount,
                  teamName: teamName,
                  presentationMode: true,
                ),
                if (benchPlayers.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.md),
                  BenchBar(
                    players: benchPlayers,
                    compact: true,
                    title: 'البدلاء',
                  ),
                ],
                const SizedBox(height: AppDimensions.md),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'EL7REEF • الحريف',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

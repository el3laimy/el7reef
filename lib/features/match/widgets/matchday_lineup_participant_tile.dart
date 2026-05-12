import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_status_badge.dart';

class MatchdayLineupParticipantTile extends StatelessWidget {
  final MatchdayController controller;
  final MatchdayParticipantDraft participant;
  final bool enabled;

  const MatchdayLineupParticipantTile({
    super.key,
    required this.controller,
    required this.participant,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final slot = controller.lineupSlotFor(participant.selectionId);
    final isEligible =
        controller.statusFor(participant.selectionId) ==
                MatchAttendanceStatus.present ||
            controller.statusFor(participant.selectionId) ==
                MatchAttendanceStatus.late;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  participant.displayName,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (participant.isGuest)
                const MatchdayStatusBadge(label: 'ضيف', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isEligible ? 'مؤهل للتشكيل' : 'لاعب غير مؤهل قبل تأكيد حضوره.',
            style: AppTextStyles.labelSmall.copyWith(
              color: isEligible ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('خارج التشكيل'),
                selected: slot == null,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          null,
                        )
                    : null,
              ),
              ChoiceChip(
                label: const Text('أساسي'),
                selected: slot == MatchdayLineupSlot.starter,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          MatchdayLineupSlot.starter,
                        )
                    : null,
              ),
              ChoiceChip(
                label: const Text('احتياط'),
                selected: slot == MatchdayLineupSlot.bench,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          MatchdayLineupSlot.bench,
                        )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

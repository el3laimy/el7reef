import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_attendance_avatar.dart';
import 'matchday_status_badge.dart';

class MatchdayParticipantAttendanceTile extends StatelessWidget {
  final MatchdayController controller;
  final MatchdayParticipantDraft participant;
  final bool enabled;

  const MatchdayParticipantAttendanceTile({
    super.key,
    required this.controller,
    required this.participant,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final currentStatus = controller.statusFor(participant.selectionId);
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
              MatchdayAttendanceAvatar(
                name: participant.displayName,
                status: currentStatus,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
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
                          const MatchdayStatusBadge(
                            label: 'ضيف',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [participant.position, participant.statusSeedLabel]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' • '),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MatchAttendanceStatus.values
                .map(
                  (status) => ChoiceChip(
                    label: Text(attendanceStatusLabel(status)),
                    selected: currentStatus == status,
                    selectedColor: attendanceChipColor(status),
                    onSelected: enabled
                        ? (_) => controller.setAttendanceStatus(
                              participant.selectionId,
                              status,
                            )
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

String attendanceStatusLabel(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.pending => 'انتظار',
    MatchAttendanceStatus.present => 'حاضر',
    MatchAttendanceStatus.late => 'متأخر',
    MatchAttendanceStatus.absent => 'غائب',
    MatchAttendanceStatus.excused => 'معذور',
  };
}

Color attendanceChipColor(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.present => AppColors.success.withValues(alpha: 0.2),
    MatchAttendanceStatus.late => AppColors.warning.withValues(alpha: 0.2),
    MatchAttendanceStatus.absent => AppColors.error.withValues(alpha: 0.2),
    MatchAttendanceStatus.excused => AppColors.info.withValues(alpha: 0.2),
    MatchAttendanceStatus.pending => AppColors.surface,
  };
}

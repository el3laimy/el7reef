import 'package:flutter/material.dart';

import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_participant_attendance_tile.dart';

class MatchdayAttendanceSection extends StatelessWidget {
  final MatchdayController controller;

  const MatchdayAttendanceSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final locked = controller.isLineupLocked;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Check-in والحضور', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            locked
                ? 'تم تثبيت الحضور بعد قفل التشكيل. يمكنك مراجعة الحالة الحالية فقط.'
                : 'حدّد حالة كل لاعب قبل قفل التشكيل.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          ...controller.participants.map(
            (participant) => MatchdayParticipantAttendanceTile(
              controller: controller,
              participant: participant,
              enabled: !locked && !controller.isSubmitting.value,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: locked || controller.isSubmitting.value
                  ? null
                  : controller.submitCheckIn,
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: Text(
                controller.activeCheckIn.value == null
                    ? 'تنفيذ check-in'
                    : 'تحديث check-in',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

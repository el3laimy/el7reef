import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_participant_attendance_tile.dart';

class MatchdayAttendanceSection extends StatefulWidget {
  final MatchdayController controller;

  const MatchdayAttendanceSection({super.key, required this.controller});

  @override
  State<MatchdayAttendanceSection> createState() =>
      _MatchdayAttendanceSectionState();
}

class _MatchdayAttendanceSectionState extends State<MatchdayAttendanceSection> {
  bool _showPlayerStatuses = false;
  String? _sideKey;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currentSideKey = controller.selectedSideKey.value;
    if (_sideKey != currentSideKey) {
      _sideKey = currentSideKey;
      _showPlayerStatuses = false;
    }
    final locked = controller.isLineupLocked;
    final hasCheckIn = controller.activeCheckIn.value != null;

    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. تأكيد الحضور', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            locked
                ? 'تم تثبيت الحضور بعد قفل التشكيل. يمكنك مراجعة الحالة الحالية فقط.'
                : 'حدّد الاستثناءات فقط، أو اعتمد حضور القائمة بالكامل.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (!locked && !hasCheckIn) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : controller.submitAllPresentCheckIn,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('اعتماد حضور الفريق بالكامل'),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
          ],
          if (hasCheckIn) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'تم اعتماد حضور ${controller.participants.length} لاعبًا',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimaryTinted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],
          if (!locked) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('matchday-attendance-details-toggle'),
                onPressed: () =>
                    setState(() => _showPlayerStatuses = !_showPlayerStatuses),
                icon: Icon(
                  _showPlayerStatuses
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                ),
                label: Text(
                  _showPlayerStatuses
                      ? 'إخفاء حالات اللاعبين'
                      : hasCheckIn
                      ? 'مراجعة أو تعديل الحالات'
                      : 'تحديد استثناءات الحضور',
                ),
              ),
            ),
          ],
          if (_showPlayerStatuses || locked) ...[
            const SizedBox(height: AppDimensions.md),
            ...controller.participants.map(
              (participant) => MatchdayParticipantAttendanceTile(
                controller: controller,
                participant: participant,
                enabled: !locked && !controller.isSubmitting.value,
              ),
            ),
            if (!locked) ...[
              const SizedBox(height: AppDimensions.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : controller.submitCheckIn,
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  label: Text(
                    hasCheckIn ? 'تحديث حالات الحضور' : 'حفظ حالات الحضور',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

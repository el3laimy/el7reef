import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_lineup_participant_tile.dart';
import 'matchday_snapshot_readonly_view.dart';

class MatchdayLineupSection extends StatelessWidget {
  final MatchdayController controller;

  const MatchdayLineupSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.activeSnapshot.value;
    final startersCount = controller.lineupDrafts.values
        .where((value) => value == MatchdayLineupSlot.starter.name)
        .length;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('2. قفل التشكيل', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            controller.requiredStarterCount == null
                ? 'اختر أساسيًا واحدًا على الأقل ثم اقفل التشكيل.'
                : 'الأساسيون المختارون: $startersCount / ${controller.requiredStarterCount}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (snapshot != null) ...[
            MatchdaySnapshotReadonlyView(snapshot: snapshot),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Get.toNamed(
                  AppRoutes.matchResultLineupById(controller.matchId),
                ),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('عرض تشكيلة النتيجة'),
              ),
            ),
          ] else ...[
            if (controller.selectedSide?.isRegisteredTeam == true &&
                (controller.selectedSide?.teamId ?? '').isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Get.toNamed(
                    AppRoutes.teamLineupEditorForMatch(
                      matchId: controller.matchId,
                      teamId: controller.selectedSide!.teamId!,
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('فتح محرر التشكيلة الاحترافي'),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],
            ...controller.participants.map(
              (participant) => MatchdayLineupParticipantTile(
                controller: controller,
                participant: participant,
                enabled: controller.canEditPreKickoff && !controller.isSubmitting.value,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.canEditPreKickoff && !controller.isSubmitting.value
                    ? controller.lockLineup
                    : null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('قفل التشكيل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

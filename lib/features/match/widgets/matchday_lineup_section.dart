import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_lineup_participant_tile.dart';
import 'matchday_snapshot_readonly_view.dart';

class MatchdayLineupSection extends StatefulWidget {
  final MatchdayController controller;

  const MatchdayLineupSection({super.key, required this.controller});

  @override
  State<MatchdayLineupSection> createState() => _MatchdayLineupSectionState();
}

class _MatchdayLineupSectionState extends State<MatchdayLineupSection> {
  bool _showPlayerSelection = false;
  String? _sideKey;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currentSideKey = controller.selectedSideKey.value;
    if (_sideKey != currentSideKey) {
      _sideKey = currentSideKey;
      _showPlayerSelection = false;
    }
    final snapshot = controller.activeSnapshot.value;
    final startersCount = controller.lineupDrafts.values
        .where((value) => value == MatchdayLineupSlot.starter.name)
        .length;

    return El7reefSolidSurface(
      padding: const EdgeInsets.all(AppDimensions.md),
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('matchday-lineup-details-toggle'),
                onPressed: () => setState(
                  () => _showPlayerSelection = !_showPlayerSelection,
                ),
                icon: Icon(
                  _showPlayerSelection
                      ? Icons.expand_less_rounded
                      : Icons.groups_rounded,
                ),
                label: Text(
                  _showPlayerSelection
                      ? 'إخفاء اختيار اللاعبين'
                      : 'تعديل الأساسيين والبدلاء',
                ),
              ),
            ),
            if (_showPlayerSelection) ...[
              const SizedBox(height: AppDimensions.md),
              ...controller.participants.map(
                (participant) => MatchdayLineupParticipantTile(
                  controller: controller,
                  participant: participant,
                  enabled:
                      controller.canEditPreKickoff &&
                      !controller.isSubmitting.value,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    controller.canEditPreKickoff &&
                        !controller.isSubmitting.value
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

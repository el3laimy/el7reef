import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/enums/match_status.dart';
import '../controllers/matchday_controller.dart';
import '../widgets/matchday_empty_roster_card.dart';
import '../widgets/matchday_widgets.dart';

class MatchdayScreen extends GetView<MatchdayController> {
  const MatchdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('يوم المباراة'),
        actions: [
          IconButton(
            onPressed: controller.loadMatchday,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.match.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.match.value == null) {
            return MatchdayErrorState(
              message: controller.errorMessage.value,
              onRetry: controller.loadMatchday,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadMatchday,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                MatchdayHeader(controller: controller),
                const SizedBox(height: AppDimensions.md),
                if (controller.selectedSide != null) ...[
                  MatchdayQuickStats(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdayProgressStepper(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdaySideSelector(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  if (_showStartAction(controller)) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('matchday-start-readiness-cta'),
                        onPressed: controller.isSubmitting.value
                            ? null
                            : controller.tournament.value != null
                            ? controller.startTournamentMatch
                            : () => Get.toNamed(
                                AppRoutes.matchLobbyById(controller.matchId),
                              ),
                        icon: controller.isSubmitting.value
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          controller.isSubmitting.value
                              ? 'جارٍ بدء المباراة...'
                              : controller.tournament.value != null
                              ? 'ابدأ المباراة'
                              : 'راجع الجاهزية وابدأ المباراة',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                  ],
                  if (controller.participants.isEmpty) ...[
                    MatchdayEmptyRosterCard(controller: controller),
                  ] else ...[
                    MatchdayAttendanceSection(controller: controller),
                    const SizedBox(height: AppDimensions.md),
                    MatchdayLineupSection(controller: controller),
                    const SizedBox(height: AppDimensions.md),
                    MatchdaySubstitutionSection(controller: controller),
                  ],
                ] else ...[
                  MatchdaySideSelector(controller: controller),
                ],
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _showStartAction(MatchdayController controller) {
    if (controller.match.value?.status != MatchStatus.open ||
        controller.activeCheckIn.value?.isCheckedIn != true) {
      return false;
    }
    return controller.tournament.value == null ||
        controller.canStartTournamentMatch;
  }
}

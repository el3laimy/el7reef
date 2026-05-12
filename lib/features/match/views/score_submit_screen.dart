import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/participant_ref.dart';
import '../controllers/score_submit_controller.dart';

class ScoreSubmitScreen extends StatelessWidget {
  const ScoreSubmitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScoreSubmitController controller = Get.find<ScoreSubmitController>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إحصائيات المباراة وتأكيد النتيجة'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Text(
                  controller.errorMessage.value,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: Get.mediaQuery.padding.top + kToolbarHeight + 10,
              ),
              _buildScoreInput(controller),
              if (controller.fullRosterErrorMessage.value.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                _buildRosterErrorBanner(
                  controller.fullRosterErrorMessage.value,
                ),
              ],
              const SizedBox(height: AppDimensions.lg),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.pagePadding,
                    right: AppDimensions.pagePadding,
                    bottom: 120, // space for sticky button
                  ),
                  children: [
                    Text(
                      controller.teamASideName.value,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (controller.teamAScoringParticipants.isEmpty)
                      _buildNoScoringParticipantsNote()
                    else
                      ...controller.teamAScoringParticipants.map(
                        (participant) => _buildParticipantScoringRow(
                          participant,
                          controller,
                        ),
                      ),

                    const SizedBox(height: AppDimensions.xl),

                    Text(
                      controller.teamBSideName.value,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    if (controller.teamBScoringParticipants.isEmpty)
                      _buildNoScoringParticipantsNote()
                    else
                      ...controller.teamBScoringParticipants.map(
                        (participant) => _buildParticipantScoringRow(
                          participant,
                          controller,
                        ),
                      ),

                    const SizedBox(height: AppDimensions.xl),
                    if (controller.allParticipants.isNotEmpty) ...[
                      Text(
                        'أفضل لاعب (MVP)',
                        style: AppTextStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      _buildMvpSelector(controller),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePadding,
          ),
          child: SizedBox(
            width: double.infinity,
            child: El7reefButton(
              text: 'حفظ النتيجة ⚽',
              isLoading: controller.isLoading.value,
              onPressed: () {
                _handleSubmit(context, controller);
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(
    BuildContext context,
    ScoreSubmitController controller,
  ) async {
    final updatedMatch = await controller.submit();
    if (updatedMatch == null || !context.mounted) return;

    Get.bottomSheet(
      _ResultSubmitSuccessSheet(
        scoreLine: _scoreLine(updatedMatch, controller),
        onShareResult: () {
          Get.back();
          Get.offNamed(AppRoutes.matchResultLineupById(updatedMatch.id));
        },
        onReturnToMatch: () {
          Get.back();
          Get.back(result: updatedMatch);
        },
        hasAttributedGoals: controller.hasAnyAttributedGoals,
        hasUnattributedGoals: controller.hasAnyUnattributedGoals,
      ),
      isScrollControlled: true,
    );
  }

  String? _scoreLine(Match match, ScoreSubmitController controller) {
    final scoreA = match.scoreTeamA;
    final scoreB = match.scoreTeamB;
    if (scoreA == null || scoreB == null) return null;
    return '${controller.teamASideName.value} $scoreA - $scoreB ${controller.teamBSideName.value}';
  }

  Widget _buildScoreInput(ScoreSubmitController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('النتيجة النهائية', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'أدخل النتيجة مباشرة، ووزّع الأهداف على اللاعبين المتاحين عند الحاجة.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: _buildTeamScoreField(
                    label: controller.teamASideName.value,
                    color: AppColors.primary,
                    textController: controller.teamAScoreController,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                  ),
                  child: Text('VS', style: AppTextStyles.titleLarge),
                ),
                Expanded(
                  child: _buildTeamScoreField(
                    label: controller.teamBSideName.value,
                    color: AppColors.error,
                    textController: controller.teamBScoreController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildGoalSummary(
                    controller.teamAGoalSummary,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _buildGoalSummary(
                    controller.teamBGoalSummary,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSummary(
    ScoreSideGoalSummary summary, {
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نتيجة الفريق: ${summary.teamScore}',
            style: AppTextStyles.labelMedium.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            'الأهداف المنسوبة: ${summary.attributedGoals}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (summary.hasUnattributedGoals) ...[
            const SizedBox(height: 4),
            Text(
              'أهداف غير منسوبة: ${summary.unattributedGoals}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 2),
            Text(
              'لن تظهر في الهدافين.',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (summary.isOverAttributed) ...[
            const SizedBox(height: 4),
            Text(
              ScoreSubmitController.attributionOverScoreMessage,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRosterErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                '$message يمكنك حفظ النتيجة فقط، لكن اختيارات الهدافين وMVP قد تكون غير مكتملة.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreField({
    required String label,
    required Color color,
    required TextEditingController textController,
  }) {
    return TextField(
      controller: textController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: AppTextStyles.displayLarge.copyWith(color: color),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildNoScoringParticipantsNote() {
    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Text(
        'لا يوجد لاعبون متاحون لهذا الطرف. أضف لاعبين للفريق أو لقائمة المباراة قبل تسجيل الأهداف.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildParticipantScoringRow(
    ParticipantRef participant,
    ScoreSubmitController controller,
  ) {
    final isRegisteredPlayer =
        participant.kind == ParticipantRefKind.player &&
        controller.playerStats.containsKey(participant.id);

    return GlassmorphicContainer(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppDimensions.xs,
                  runSpacing: AppDimensions.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      participant.displayName,
                      style: AppTextStyles.titleMedium,
                    ),
                    if (participant.kind != ParticipantRefKind.player)
                      _buildParticipantBadge(participant),
                  ],
                ),
              ),
              if (isRegisteredPlayer)
                _buildCardIndicators(participant.id, controller),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: AppDimensions.lg,
            runSpacing: AppDimensions.sm,
            children: [
              _buildParticipantGoalCounter(participant, controller),
              if (isRegisteredPlayer) ...[
                _buildStatCounter(
                  'أسيست',
                  'assists',
                  participant.id,
                  controller,
                ),
                _buildStatCounter('تصدي', 'saves', participant.id, controller),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildParticipantBadge(ParticipantRef participant) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Text(
        _participantKindLabel(participant),
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }

  String _participantKindLabel(ParticipantRef participant) {
    switch (participant.kind) {
      case ParticipantRefKind.player:
        return 'لاعب';
      case ParticipantRefKind.guestPlayer:
        return 'ضيف';
      case ParticipantRefKind.matchSidePlayer:
        return 'قائمة المباراة';
    }
  }

  Widget _buildCardIndicators(
    String playerId,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final st = controller.playerStats[playerId]!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => controller.toggleCard(playerId, 'yellowCard'),
            child: Container(
              width: 16,
              height: 24,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: st['yellowCard'] == true
                    ? Colors.yellow
                    : AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => controller.toggleCard(playerId, 'redCard'),
            child: Container(
              width: 16,
              height: 24,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: st['redCard'] == true
                    ? Colors.red
                    : AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildParticipantGoalCounter(
    ParticipantRef participant,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final val = controller.goalsForParticipant(participant);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أهداف',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(
                Icons.remove,
                () => controller.decrementParticipantGoals(participant),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$val', style: AppTextStyles.titleLarge),
              ),
              _btn(
                Icons.add,
                () => controller.incrementParticipantGoals(participant),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildStatCounter(
    String label,
    String key,
    String playerId,
    ScoreSubmitController controller,
  ) {
    return Obx(() {
      final val = controller.playerStats[playerId]?[key] ?? 0;
      return Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(Icons.remove, () => controller.decrementStat(playerId, key)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$val', style: AppTextStyles.titleLarge),
              ),
              _btn(Icons.add, () => controller.incrementStat(playerId, key)),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceBorder.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildMvpSelector(ScoreSubmitController controller) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: controller.allParticipants.map((participant) {
        final participantKey = controller.participantKey(participant);
        final isSelected = controller.selectedMvpKey.value == participantKey;
        return ChoiceChip(
          label: Text(_mvpChoiceLabel(participant)),
          selected: isSelected,
          onSelected: (_) =>
              controller.selectMvp(isSelected ? '' : participantKey),
          selectedColor: AppColors.primarySurface,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.secondary : AppColors.textPrimary,
          ),
        );
      }).toList(),
    );
  }

  String _mvpChoiceLabel(ParticipantRef participant) {
    if (participant.kind == ParticipantRefKind.player) {
      return participant.displayName;
    }
    return '${participant.displayName} (${_participantKindLabel(participant)})';
  }
}

class _ResultSubmitSuccessSheet extends StatelessWidget {
  final String? scoreLine;
  final VoidCallback onShareResult;
  final VoidCallback onReturnToMatch;
  final bool hasAttributedGoals;
  final bool hasUnattributedGoals;

  const _ResultSubmitSuccessSheet({
    required this.scoreLine,
    required this.onShareResult,
    required this.onReturnToMatch,
    required this.hasAttributedGoals,
    required this.hasUnattributedGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تم تسجيل النتيجة ✅', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.sm),
              Text(
                _successMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (scoreLine != null) ...[
                const SizedBox(height: AppDimensions.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    scoreLine!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              FilledButton.icon(
                onPressed: onShareResult,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('مشاركة النتيجة'),
              ),
              const SizedBox(height: AppDimensions.sm),
              TextButton(
                onPressed: onReturnToMatch,
                child: const Text('العودة للمباراة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _successMessage {
    if (!hasAttributedGoals) {
      return 'تم حفظ النتيجة بدون أهداف منسوبة؛ لن تُضاف أهداف للهدافين من هذه المباراة.';
    }
    if (hasUnattributedGoals) {
      return 'تم حفظ النتيجة وتسجيل الأهداف المنسوبة. الأهداف غير المنسوبة لن تظهر في الهدافين.';
    }
    return 'تم حفظ النتيجة وتسجيل الأهداف المنسوبة للمشاركة مع اللاعبين.';
  }
}

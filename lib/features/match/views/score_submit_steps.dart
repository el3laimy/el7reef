part of 'score_submit_screen.dart';

class _ScoreSubmitScoreStep extends StatelessWidget {
  final ScoreSubmitController controller;

  const _ScoreSubmitScoreStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('score-step'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePadding,
          ),
          child: El7reefSurface(
            elevated: true,
            borderColor: AppColors.primary.withValues(alpha: 0.24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const El7reefBadge(
                  label: 'تسجيل رسمي',
                  color: AppColors.primary,
                  icon: Icons.verified_rounded,
                ),
                const SizedBox(height: AppDimensions.md),
                Text('النتيجة النهائية', style: AppTextStyles.titleLarge),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'أدخل النتيجة، نسب الأهداف، واختار MVP. البيانات دي هتطلع ترتيب وكروت فخر.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Obx(
                  () => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ScoreSubmitTeamScoreField(
                              label: controller.teamASideName.value,
                              color: AppColors.primary,
                              textController: controller.teamAScoreController,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.xs,
                            ),
                            child: Text(
                              'ضد',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textSecondaryTinted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _ScoreSubmitTeamScoreField(
                              label: controller.teamBSideName.value,
                              color: AppColors.accent,
                              textController: controller.teamBScoreController,
                            ),
                          ),
                        ],
                      ),
                      if (controller.requiresPenaltyShootout) ...[
                        const SizedBox(height: AppDimensions.lg),
                        _PenaltyShootoutSection(controller: controller),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreSubmitScorersStep extends StatelessWidget {
  final Widget attributionOverview;
  final Widget teamASection;
  final Widget teamBSection;

  const _ScoreSubmitScorersStep({
    required this.attributionOverview,
    required this.teamASection,
    required this.teamBSection,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('scorers-step'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.sm,
        AppDimensions.pagePadding,
        120,
      ),
      children: [
        attributionOverview,
        const SizedBox(height: AppDimensions.md),
        teamASection,
        const SizedBox(height: AppDimensions.lg),
        teamBSection,
      ],
    );
  }
}

class _ScoreSubmitMvpStep extends StatelessWidget {
  final Widget? selector;

  const _ScoreSubmitMvpStep({this.selector});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('mvp-step'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.sm,
        AppDimensions.pagePadding,
        120,
      ),
      children: [
        El7reefSurface(
          borderColor: AppColors.actionPrimary.withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const El7reefBadge(
                label: 'لحظة الفخر',
                color: AppColors.actionPrimary,
                icon: Icons.star_rounded,
              ),
              const SizedBox(height: AppDimensions.md),
              Text('اختار نجم المباراة', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppDimensions.xs),
              Text(
                'اللاعب المسجل أو الضيف له نفس الحق في MVP وكارت المشاركة.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              selector ??
                  Text(
                    'لا توجد أسماء متاحة الآن. يمكنك المتابعة بدون MVP أو الرجوع لإضافة اللاعبين.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreSubmitReviewStep extends StatelessWidget {
  final ScoreSubmitController controller;
  final Widget attributionOverview;

  const _ScoreSubmitReviewStep({
    required this.controller,
    required this.attributionOverview,
  });

  @override
  Widget build(BuildContext context) {
    final mvp = controller.selectedMvpSelection?.actor;
    return ListView(
      key: const ValueKey('review-step'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pagePadding,
        AppDimensions.sm,
        AppDimensions.pagePadding,
        120,
      ),
      children: [
        Text('راجع قبل الاعتماد', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppDimensions.xs),
        Text(
          'لن تُكتب النتيجة أو أحداث الأهداف وMVP إلا بعد الضغط على زر الاعتماد.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryTinted,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        El7reefSurface(
          elevated: true,
          child: Column(
            children: [
              _ReviewRow(
                label: controller.teamASideName.value,
                value: controller.teamAGoalSummary.teamScore.toString(),
              ),
              const Divider(),
              _ReviewRow(
                label: controller.teamBSideName.value,
                value: controller.teamBGoalSummary.teamScore.toString(),
              ),
              if (controller.requiresPenaltyShootout) ...[
                const Divider(),
                _ReviewRow(
                  label: 'ركلات الترجيح — ${controller.teamASideName.value}',
                  value: controller.teamAPenaltyScoreText.value,
                ),
                const Divider(),
                _ReviewRow(
                  label: 'ركلات الترجيح — ${controller.teamBSideName.value}',
                  value: controller.teamBPenaltyScoreText.value,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        attributionOverview,
        const SizedBox(height: AppDimensions.md),
        El7reefSurface(
          borderColor: AppColors.actionPrimary.withValues(alpha: 0.28),
          child: _ReviewRow(
            label: 'نجم المباراة',
            value: mvp?.displayName ?? 'بدون اختيار',
          ),
        ),
      ],
    );
  }
}

class _ScoreSubmitTeamScoreField extends StatelessWidget {
  final String label;
  final Color color;
  final TextEditingController textController;

  const _ScoreSubmitTeamScoreField({
    required this.label,
    required this.color,
    required this.textController,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: AppTextStyles.displayLarge.copyWith(color: color),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PenaltyShootoutSection extends StatelessWidget {
  final ScoreSubmitController controller;

  const _PenaltyShootoutSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'نتيجة ركلات الترجيح المطلوبة لحسم مباراة الإقصاء',
      child: El7reefSurface(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderColor: AppColors.accent.withValues(alpha: 0.32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_soccer_rounded,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    'ركلات الترجيح',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.accentLight,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'التعادل في الإقصائيات لازم يتحسم. الركلات لا تُضاف للأهداف أو ترتيب الهدافين.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondaryTinted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Row(
              children: [
                Expanded(
                  child: _ScoreSubmitTeamScoreField(
                    label: controller.teamASideName.value,
                    color: AppColors.primary,
                    textController: controller.teamAPenaltyScoreController,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.xs,
                  ),
                  child: Text(
                    '–',
                    textDirection: TextDirection.ltr,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ),
                Expanded(
                  child: _ScoreSubmitTeamScoreField(
                    label: controller.teamBSideName.value,
                    color: AppColors.accent,
                    textController: controller.teamBPenaltyScoreController,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

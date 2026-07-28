import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_badge.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';
import '../../../core/widgets/el7reef_surface.dart';
import '../../../core/widgets/section_state_card.dart';
import '../controllers/tournament_operations_controller.dart';
import '../widgets/tournament_widgets.dart';
import '../widgets/tournament_visual_language.dart';

/// شاشة غرفة تحكم البطولة للمنظم — مطورة بالكامل لتسهيل التشغيل والإدارة بصرياً
class TournamentOperationsDashboardScreen
    extends GetView<TournamentOperationsController> {
  const TournamentOperationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('غرفة تحكم البطولة'),
        centerTitle: true,
        actions: [
          Obx(() {
            if (controller.isActing.value) {
              return const Padding(
                padding: EdgeInsetsDirectional.only(end: AppDimensions.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final tournament = controller.tournament.value;
          if (tournament == null) {
            return TournamentStateMessage(
              title: 'تعذر تحميل مركز التشغيل',
              message: controller.errorMessage.value.isEmpty
                  ? 'لم نتمكن من العثور على البطولة المطلوبة.'
                  : controller.errorMessage.value,
            );
          }

          return SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                children: [
                  // ── Hero Card (لوحة تحكم الملعب) ──
                  _DashboardHero(
                    title: tournament.name,
                    status: tournament.status,
                    statusLabel: controller.statusLabelFor(tournament.status),
                    activeParticipantsCount: controller.activeParticipantsCount,
                    isFinalized: tournament.participantListFinalizedAt != null,
                  ),

                  // ── رسائل الخطأ والتنبيهات ──
                  if (controller.errorMessage.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.md),
                      child: SectionStateCard.error(
                        message: controller.errorMessage.value,
                        actionLabel: null,
                      ),
                    ),

                  // ── تحذير ترحيل البيانات ──
                  if (controller.isBlockedByManualMigration)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.md),
                      child: _WarningCard(
                        title: 'تحتاج مراجعة تشغيل ⚠️',
                        message:
                            'هذه البطولة تحتاج ترحيل بيانات يدوي قبل السماح بالتشغيل الكامل.',
                      ),
                    ),

                  const SizedBox(height: AppDimensions.md),

                  // ── معالج تشغيل البطولة والخطوة الأساسية ──
                  _OperationsWizardCard(controller: controller),

                  const SizedBox(height: AppDimensions.md),

                  // ── نبض البطولة (العدادات السريعة) ──
                  TournamentOperationsMetricsCard(controller: controller),

                  const SizedBox(height: AppDimensions.lg),

                  Text(
                    'ملعب المنافسة',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _CompetitionCommandDeck(
                    controller: controller,
                    tournamentId: tournament.id,
                  ),

                  const SizedBox(height: AppDimensions.lg),

                  Text(
                    'أهل البطولة',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  _PeopleCommandDeck(
                    controller: controller,
                    tournamentId: tournament.id,
                  ),

                  const SizedBox(height: AppDimensions.md),

                  // ── إجراءات التشغيل الإضافية ──
                  if (_hasAvailableSecondaryActions(controller)) ...[
                    const SizedBox(height: AppDimensions.md),
                    _SecondaryOpsSection(controller: controller),
                  ],

                  // ── أدوات الصيانة للمشاكل الفنية ──
                  if (controller.shouldShowMaintenanceTools) ...[
                    const SizedBox(height: AppDimensions.md),
                    _MaintenanceSection(controller: controller),
                  ],

                  const SizedBox(height: AppDimensions.xxl),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  bool _hasAvailableSecondaryActions(
    TournamentOperationsController controller,
  ) {
    return controller.canManualAddParticipants ||
        (controller.shouldShowMaintenanceTools &&
            !controller.isBlockedByManualMigration) ||
        controller.canRegenerateGroupStage;
  }
}

class _CompetitionCommandDeck extends StatelessWidget {
  final TournamentOperationsController controller;
  final String tournamentId;

  const _CompetitionCommandDeck({
    required this.controller,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    final groupsTile = _CommandTile.stacked(
      title: 'المجموعات',
      value: '${controller.groups.length}',
      detail: 'مجموعات البطولة',
      icon: Icons.grid_view_rounded,
      accent: AppColors.primary,
      onTap: () => Get.toNamed(AppRoutes.tournamentGroupsById(tournamentId)),
    );
    final standingsTile = _CommandTile.stacked(
      title: 'الترتيب',
      value: '${controller.standings.length}',
      detail: 'جداول محدثة',
      icon: Icons.leaderboard_rounded,
      accent: AppColors.info,
      onTap: () => Get.toNamed(AppRoutes.tournamentStandingsById(tournamentId)),
    );
    final stackTiles = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Column(
      children: [
        _CommandTile.prominent(
          title: 'المباريات',
          value: '${controller.fixtures.length}',
          detail: 'افتح جدول اللعب وسجّل النتائج',
          icon: Icons.sports_soccer_rounded,
          accent: AppColors.primary,
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentFixturesById(tournamentId)),
        ),
        const SizedBox(height: AppDimensions.sm),
        if (stackTiles) ...[
          groupsTile,
          const SizedBox(height: AppDimensions.sm),
          standingsTile,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: groupsTile),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: standingsTile),
            ],
          ),
        const SizedBox(height: AppDimensions.sm),
        _CommandTile.horizontal(
          title: 'الإقصائيات',
          value: controller.knockoutBracket.value == null
              ? 'لم تبدأ'
              : '${controller.knockoutTies.length} مواجهة',
          detail: controller.knockoutBracket.value == null
              ? 'تُفتح بعد اكتمال التأهل'
              : 'تابع الطريق حتى البطل',
          icon: Icons.account_tree_rounded,
          accent: AppColors.accent,
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentBracketById(tournamentId)),
        ),
      ],
    );
  }
}

class _PeopleCommandDeck extends StatelessWidget {
  final TournamentOperationsController controller;
  final String tournamentId;

  const _PeopleCommandDeck({
    required this.controller,
    required this.tournamentId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TournamentLinkTile(
          title: 'الفرق المشاركة',
          subtitle: '${controller.participants.length} فريق في البطولة',
          icon: Icons.groups_rounded,
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentParticipantsById(tournamentId)),
        ),
        TournamentLinkTile(
          title: 'المساعدين',
          subtitle: 'الصلاحيات ومسؤوليات يوم المباراة',
          icon: Icons.admin_panel_settings_rounded,
          onTap: () =>
              Get.toNamed(AppRoutes.tournamentAssistantsById(tournamentId)),
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final _CommandTileLayout layout;

  const _CommandTile.prominent({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : layout = _CommandTileLayout.prominent;

  const _CommandTile.horizontal({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : layout = _CommandTileLayout.horizontal;

  const _CommandTile.stacked({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.accent,
    required this.onTap,
  }) : layout = _CommandTileLayout.stacked;

  @override
  Widget build(BuildContext context) {
    final content = layout != _CommandTileLayout.stacked
        ? Row(
            children: [
              _iconBox(),
              const SizedBox(width: AppDimensions.md),
              Expanded(child: _copy()),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.textSecondaryTinted,
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(),
              const SizedBox(height: AppDimensions.sm),
              _copy(),
            ],
          );

    return Material(
      color: layout == _CommandTileLayout.prominent
          ? AppColors.surfaceRaised
          : accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: BorderSide(color: accent.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: layout == _CommandTileLayout.prominent ? 96 : 104,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(icon, color: accent, size: 21),
    );
  }

  Widget _copy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: AppTextStyles.bodyMedium.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondaryTinted,
          ),
        ),
      ],
    );
  }
}

enum _CommandTileLayout { prominent, horizontal, stacked }

// ══════════════════════════════════════════
// ── لوحة ترويسة التشغيل (Dashboard Hero) ──
// ══════════════════════════════════════════
class _DashboardHero extends StatelessWidget {
  final String title;
  final TournamentStatus status;
  final String statusLabel;
  final int activeParticipantsCount;
  final bool isFinalized;

  const _DashboardHero({
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.activeParticipantsCount,
    required this.isFinalized,
  });

  @override
  Widget build(BuildContext context) {
    final baseSpec = tournamentVisualSpec(status);
    final spec = TournamentVisualSpec(
      statusLabel: statusLabel,
      stageLabel: baseSpec.stageLabel,
      icon: baseSpec.icon,
      accent: baseSpec.accent,
      stageIndex: baseSpec.stageIndex,
    );
    return El7reefGlassSurface(
      role: El7reefGlassRole.hero,
      tone: El7reefGlassTone.competitive,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: TournamentFieldPattern(
          color: spec.accent,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TournamentStatusPill(spec: spec),
                    _DashboardLockPill(isFinalized: isFinalized),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Icon(Icons.groups_rounded, color: spec.accent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$activeParticipantsCount فريق نشط جاهز',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textPrimaryTinted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),
                TournamentStageRail(
                  activeIndex: spec.stageIndex,
                  accent: spec.accent,
                  semanticsLabel: spec.stageLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLockPill extends StatelessWidget {
  final bool isFinalized;

  const _DashboardLockPill({required this.isFinalized});

  @override
  Widget build(BuildContext context) {
    final color = isFinalized ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFinalized ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isFinalized ? 'مغلقة تماماً' : 'مفتوحة للتعديل',
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── معالج تشغيل البطولة: خطوة واحدة واضحة في كل مرة ──
class _OperationsWizardCard extends StatelessWidget {
  final TournamentOperationsController controller;

  const _OperationsWizardCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final action = _nextAction();
    final steps = _wizardSteps();
    final completedSteps = steps
        .where(
          (step) =>
              step.state == _WizardStepState.done ||
              step.state == _WizardStepState.skipped,
        )
        .length;
    final progress = steps.isEmpty ? 0.0 : completedSteps / steps.length;

    return El7reefSurface(
      color: AppColors.backgroundLight,
      borderColor: AppColors.primary.withValues(alpha: 0.36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جاهزية التشغيل',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'معالج تشغيل البطولة',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'نفّذ خطوات البطولة بالترتيب: فرق، جدول، نتائج، ثم تتويج.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceBorder,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            '$completedSteps من ${steps.length} مراحل جاهزة',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondaryTinted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          ...steps.asMap().entries.map(
            (entry) => _WizardStepRow(
              step: entry.value,
              index: entry.key + 1,
              isLast: entry.key == steps.length - 1,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          const Divider(color: AppColors.surfaceBorder, height: 1),
          const SizedBox(height: AppDimensions.md),
          _WizardDecisionPanel(
            action: action,
            isActing: controller.isActing.value,
            fallbackDetail: _noActionDetail(),
            fallbackRequirements: _requirementsForNoAction(steps),
            onConfirmAndRun: (selectedAction) =>
                _confirmAndRun(context, selectedAction),
          ),
        ],
      ),
    );
  }

  List<_WizardStepData> _wizardSteps() {
    final currentTournament = controller.tournament.value;
    if (currentTournament == null) {
      return const <_WizardStepData>[];
    }

    final hasFinalizedParticipants =
        currentTournament.participantListFinalizedAt != null;
    final hasPublishedFixtures = controller.hasPublishedFixtures;
    final hasGroupStage = controller.hasGroupStage;
    final hasKnockoutStage = controller.hasKnockoutStage;

    return <_WizardStepData>[
      _WizardStepData(
        title: 'قائمة الفرق',
        detail: hasFinalizedParticipants
            ? 'تم قفل الفرق المشاركة، يمكن الاعتماد عليها في الجدول.'
            : controller.activeParticipantsCount >= 2
            ? 'الفريقان على الأقل جاهزان. اقفل القائمة قبل توليد الجدول.'
            : 'تحتاج فريقين نشطين على الأقل قبل قفل القائمة.',
        icon: Icons.groups_rounded,
        state: hasFinalizedParticipants
            ? _WizardStepState.done
            : controller.canFinalizeParticipantsAction
            ? _WizardStepState.current
            : _WizardStepState.waiting,
      ),
      _WizardStepData(
        title: 'دور المجموعات',
        detail: currentTournament.format == TournamentFormat.knockoutOnly
            ? 'غير مطلوب، هذه البطولة تبدأ من الإقصاء مباشرة.'
            : hasGroupStage
            ? 'تم إنشاء المجموعات ومبارياتها.'
            : controller.canStartGroupStageAction
            ? 'المشاركون مقفلون. ابدأ توزيع الفرق وتوليد المباريات.'
            : 'ينتظر قفل قائمة الفرق أولًا.',
        icon: Icons.grid_view_rounded,
        state: currentTournament.format == TournamentFormat.knockoutOnly
            ? _WizardStepState.skipped
            : hasGroupStage
            ? _WizardStepState.done
            : controller.canStartGroupStageAction
            ? _WizardStepState.current
            : _WizardStepState.waiting,
      ),
      _WizardStepData(
        title: 'نشر الجدول',
        detail: hasPublishedFixtures
            ? 'تم إتاحة ${controller.releasedFixturesCount} مباراة للفرق.'
            : controller.canPublishFixtures
            ? 'راجع المسودات ثم انشر ${controller.draftFixturesCount} مباراة.'
            : controller.fixtures.isEmpty
            ? 'ينتظر توليد المباريات من المرحلة السابقة.'
            : 'كل المباريات الحالية منشورة أو لا توجد مسودات تحتاج نشر.',
        icon: Icons.publish_rounded,
        state: hasPublishedFixtures
            ? _WizardStepState.done
            : controller.canPublishFixtures
            ? _WizardStepState.current
            : _WizardStepState.waiting,
      ),
      _WizardStepData(
        title: 'مرحلة الإقصاء',
        detail: currentTournament.format == TournamentFormat.groupsOnly
            ? 'غير مطلوبة لهذا النوع من البطولات.'
            : hasKnockoutStage
            ? 'تم إنشاء شجرة الإقصاء.'
            : controller.canStartKnockoutAction
            ? 'النتائج والمؤهلون جاهزون لبناء شجرة الإقصاء.'
            : currentTournament.format == TournamentFormat.knockoutOnly
            ? 'ينتظر قفل قائمة الفرق.'
            : 'ينتظر اكتمال نتائج دور المجموعات رسميًا.',
        icon: Icons.account_tree_rounded,
        state: currentTournament.format == TournamentFormat.groupsOnly
            ? _WizardStepState.skipped
            : hasKnockoutStage
            ? _WizardStepState.done
            : controller.canStartKnockoutAction
            ? _WizardStepState.current
            : _WizardStepState.waiting,
      ),
      _WizardStepData(
        title: 'تتويج البطل',
        detail: currentTournament.status == TournamentStatus.completed
            ? 'تم إغلاق البطولة وتثبيت البطل.'
            : controller.canCompleteTournamentAction
            ? 'البطل معروف الآن. أغلق البطولة وابدأ لحظة الفخر.'
            : 'ينتظر حسم النهائي أو اكتمال نتائج المرحلة الأخيرة.',
        icon: Icons.emoji_events_rounded,
        state: currentTournament.status == TournamentStatus.completed
            ? _WizardStepState.done
            : controller.canCompleteTournamentAction
            ? _WizardStepState.current
            : _WizardStepState.waiting,
      ),
    ];
  }

  String _noActionDetail() {
    if (controller.isBlockedByManualMigration) {
      return 'التشغيل متوقف حتى تتم مراجعة وترحيل بيانات البطولة يدويًا.';
    }
    final pendingActions = controller.pendingActions;
    if (pendingActions.isNotEmpty) {
      return pendingActions.first.detail;
    }
    return 'لا يوجد إجراء أساسي متاح الآن. راجع المراحل المعلقة أو انتقل إلى شاشة المباريات لتسجيل النتائج.';
  }

  List<String> _requirementsForNoAction(List<_WizardStepData> steps) {
    if (controller.isBlockedByManualMigration) {
      return const <String>[
        'مزامنة الفرق المعتمدة من أدوات الصيانة.',
        'مراجعة بيانات البطولة قبل السماح بالتشغيل.',
      ];
    }
    final waitingSteps = steps
        .where((step) => step.state == _WizardStepState.waiting)
        .take(3)
        .map((step) => step.detail)
        .toList(growable: false);
    if (waitingSteps.isNotEmpty) {
      return waitingSteps;
    }
    return const <String>['لا توجد شروط معلقة في معالج التشغيل.'];
  }

  Future<void> _confirmAndRun(BuildContext context, _OpsAction action) async {
    if (!action.needsConfirmation) {
      action.onPressed();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.confirmTitle ?? action.label),
        content: Text(
          action.confirmMessage ?? 'هل أنت متأكد من تنفيذ هذا الإجراء؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تأكيد التفعيل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      action.onPressed();
    }
  }

  _OpsAction? _nextAction() {
    final action = controller.nextOperationalAction;
    if (action == null) return null;
    return _OpsAction(
      label: action.label,
      icon: _nextActionIcon(action.kind),
      onPressed: _nextActionCallback(action),
      detail: action.detail,
      requirements: action.requirements,
      needsConfirmation: action.needsConfirmation,
      confirmTitle: action.confirmTitle,
      confirmMessage: action.confirmMessage,
    );
  }

  IconData _nextActionIcon(TournamentOpsNextActionKind kind) => switch (kind) {
    TournamentOpsNextActionKind.recordLiveScore => Icons.sports_score_rounded,
    TournamentOpsNextActionKind.reviewPendingScore => Icons.fact_check_rounded,
    TournamentOpsNextActionKind.prepareUpcomingFixture =>
      Icons.sports_soccer_rounded,
    TournamentOpsNextActionKind.addParticipant => Icons.group_add_rounded,
    TournamentOpsNextActionKind.finalizeParticipants => Icons.verified_rounded,
    TournamentOpsNextActionKind.startGroupStage => Icons.groups_2_rounded,
    TournamentOpsNextActionKind.publishFixtures => Icons.publish_rounded,
    TournamentOpsNextActionKind.startKnockout => Icons.account_tree_rounded,
    TournamentOpsNextActionKind.completeTournament =>
      Icons.emoji_events_rounded,
  };

  VoidCallback _nextActionCallback(TournamentOpsNextAction action) {
    return switch (action.kind) {
      TournamentOpsNextActionKind.recordLiveScore ||
      TournamentOpsNextActionKind.reviewPendingScore => () => Get.toNamed(
        AppRoutes.scoreApprovalForMatch(action.matchId!),
      ),
      TournamentOpsNextActionKind.prepareUpcomingFixture => () => Get.toNamed(
        AppRoutes.matchDetailsById(action.matchId!),
      ),
      TournamentOpsNextActionKind.addParticipant => () => Get.toNamed(
        AppRoutes.tournamentParticipantsById(controller.tournamentId!),
      ),
      TournamentOpsNextActionKind.finalizeParticipants =>
        controller.finalizeParticipantList,
      TournamentOpsNextActionKind.startGroupStage => controller.startGroupStage,
      TournamentOpsNextActionKind.publishFixtures => controller.publishFixtures,
      TournamentOpsNextActionKind.startKnockout => controller.startKnockout,
      TournamentOpsNextActionKind.completeTournament =>
        controller.completeTournament,
    };
  }
}

enum _WizardStepState { done, current, waiting, skipped }

class _WizardStepData {
  final String title;
  final String detail;
  final IconData icon;
  final _WizardStepState state;

  const _WizardStepData({
    required this.title,
    required this.detail,
    required this.icon,
    required this.state,
  });
}

class _WizardStepRow extends StatelessWidget {
  final _WizardStepData step;
  final int index;
  final bool isLast;

  const _WizardStepRow({
    required this.step,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(step.state);
    final icon = _stateIcon(step.state);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppDimensions.sm),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: step.state == _WizardStepState.current
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceRaised.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.42)),
              ),
              child: Center(
                child: step.state == _WizardStepState.done
                    ? Icon(icon, color: color, size: 18)
                    : Text(
                        index.toString(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      El7reefBadge(
                        label: _stateLabel(step.state),
                        color: color,
                        icon: icon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.detail,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(_WizardStepState state) => switch (state) {
    _WizardStepState.done => AppColors.success,
    _WizardStepState.current => AppColors.primary,
    _WizardStepState.waiting => AppColors.textMuted,
    _WizardStepState.skipped => AppColors.info,
  };

  IconData _stateIcon(_WizardStepState state) => switch (state) {
    _WizardStepState.done => Icons.check_rounded,
    _WizardStepState.current => Icons.play_arrow_rounded,
    _WizardStepState.waiting => Icons.schedule_rounded,
    _WizardStepState.skipped => Icons.remove_circle_outline_rounded,
  };

  String _stateLabel(_WizardStepState state) => switch (state) {
    _WizardStepState.done => 'تم',
    _WizardStepState.current => 'الآن',
    _WizardStepState.waiting => 'ينتظر',
    _WizardStepState.skipped => 'غير مطلوب',
  };
}

class _WizardDecisionPanel extends StatelessWidget {
  final _OpsAction? action;
  final bool isActing;
  final String fallbackDetail;
  final List<String> fallbackRequirements;
  final Future<void> Function(_OpsAction action) onConfirmAndRun;

  const _WizardDecisionPanel({
    required this.action,
    required this.isActing,
    required this.fallbackDetail,
    required this.fallbackRequirements,
    required this.onConfirmAndRun,
  });

  @override
  Widget build(BuildContext context) {
    final selectedAction = action;
    final color = selectedAction == null ? AppColors.info : AppColors.primary;
    final requirements = selectedAction?.requirements ?? fallbackRequirements;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  selectedAction?.icon ?? Icons.fact_check_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الخطوة التالية',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedAction?.label ?? 'لا يوجد إجراء أساسي الآن',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            selectedAction?.detail ?? fallbackDetail,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondaryTinted,
              height: 1.5,
            ),
          ),
          if (requirements.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.md),
            Text(
              'شروط التفعيل',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: requirements
                  .map((requirement) => _RequirementChip(label: requirement))
                  .toList(growable: false),
            ),
          ],
          if (selectedAction != null) ...[
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isActing
                    ? null
                    : () => onConfirmAndRun(selectedAction),
                icon: Icon(selectedAction.icon),
                label: Text(
                  selectedAction.label,
                  style: AppTextStyles.buttonText.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final String label;

  const _RequirementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.surfaceBorderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.primary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondaryTinted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool needsConfirmation;
  final String? confirmTitle;
  final String? confirmMessage;
  final String? detail;
  final List<String> requirements;

  const _OpsAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.needsConfirmation = false,
    this.confirmTitle,
    this.confirmMessage,
    this.detail,
    this.requirements = const <String>[],
  });
}

// ── إجراءات تنظيمية إضافية ثانوية ──
class _SecondaryOpsSection extends StatelessWidget {
  final TournamentOperationsController controller;

  const _SecondaryOpsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (controller.canManualAddParticipants) {
      actions.add(
        _OpsButton(
          label: 'إضافة فريق يدويًا',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: controller.isActing.value
              ? null
              : () => showManualAddParticipantDialog(context, controller),
        ),
      );
    }

    if (controller.canRegenerateGroupStage) {
      actions.add(
        _OpsButton(
          label: 'إعادة توليد وتوزيع المجموعات 🔄',
          icon: Icons.refresh_rounded,
          onPressed: controller.isActing.value
              ? null
              : () => _confirmRegenerate(context),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return El7reefSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات تنظيمية إضافية',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Wrap(
            spacing: AppDimensions.sm,
            runSpacing: AppDimensions.sm,
            children: actions,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة توليد وتوزيع المجموعات ⚠️'),
        content: const Text(
          'سيقوم هذا بحذف جميع المجموعات الحالية والمباريات المسودة وتوليدها من جديد. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف وإعادة التوليد'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.regenerateGroupStage();
    }
  }
}

class _OpsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _OpsButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: AppColors.surfaceBorder),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
      ),
    );
  }
}

// ── قسم الصيانة ──
class _MaintenanceSection extends StatelessWidget {
  final TournamentOperationsController controller;

  const _MaintenanceSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final report = controller.migrationReport.value;
    return El7reefSurface(
      color: AppColors.warningSurface,
      borderColor: AppColors.warning.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_circle_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                'أدوات صيانة البطولة والبيانات ⚙️',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (report != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              'تمت مزامنة ${report.approvedRegistrationsBackfilled} تسجيل معتمد و${report.legacyTeamsBackfilled} فريق قديم بالخادم.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          _OpsButton(
            label: 'مزامنة وتصحيح الفرق المعتمدة',
            icon: Icons.sync_rounded,
            onPressed: controller.isActing.value
                ? null
                : controller.syncApprovedRegistrations,
          ),
        ],
      ),
    );
  }
}

// ── شارات ومكونات التحذيرات ──
class _WarningCard extends StatelessWidget {
  final String title;
  final String message;
  const _WarningCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return El7reefSurface(
      color: AppColors.warningSurface,
      borderColor: AppColors.warning.withValues(alpha: 0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

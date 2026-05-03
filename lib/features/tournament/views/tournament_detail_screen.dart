import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/participant_ref.dart';
import '../../../domain/entities/tournament.dart';
import '../../../services/auth_service.dart';
import '../controllers/tournament_detail_controller.dart';

class TournamentDetailScreen extends GetView<TournamentDetailController> {
  const TournamentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          final tournament = controller.tournament.value;

          if (controller.isLoading.value && tournament == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (tournament == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      controller.errorMessage.value.isEmpty
                          ? 'تعذر تحميل تفاصيل الدورة'
                          : controller.errorMessage.value,
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    El7reefButton(
                      text: 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      onPressed: controller.loadTournament,
                    ),
                  ],
                ),
              ),
            );
          }

          final isOrganizer =
              tournament.organizerId == authService.currentUserId;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(tournament.name, style: AppTextStyles.titleLarge),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.8),
                          AppColors.secondary.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 64)),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoCard(
                        tournament: tournament,
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppDimensions.md),
                      _RegistrationProgress(
                        tournament: tournament,
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: AppDimensions.md),
                      _OperationsSnapshot(
                        tournament: tournament,
                        championLabel: controller.winnerDisplayName.value,
                      ).animate().fadeIn(delay: 180.ms),
                      const SizedBox(height: AppDimensions.md),
                      _TopScorersSection(
                        isLoading: controller.isLoadingTopScorers.value,
                        errorMessage: controller.topScorersErrorMessage.value,
                        scorers: controller.topScorers,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: AppDimensions.md),
                      if (!isOrganizer &&
                          tournament.status == TournamentStatus.registration)
                        _RegisterTeamButton(
                          tournament: tournament,
                        ).animate().fadeIn(delay: 260.ms),
                      if (FeatureFlags.fantasyUiEnabled &&
                          tournament.isFantasyEnabled)
                        _FantasyLeagueButton(
                          tournament: tournament,
                        ).animate().fadeIn(delay: 300.ms),
                      if (isOrganizer)
                        _OrganizerPanel(
                          tournament: tournament,
                        ).animate().fadeIn(delay: 340.ms),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _TopScorersSection extends StatelessWidget {
  final bool isLoading;
  final String errorMessage;
  final List<TournamentTopScorerEntry> scorers;

  const _TopScorersSection({
    required this.isLoading,
    required this.errorMessage,
    required this.scorers,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_score_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('هدافو البطولة', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else if (errorMessage.isNotEmpty)
            Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            )
          else if (scorers.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لم يتم تسجيل هدافين بعد', style: AppTextStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'ستظهر هنا أهداف اللاعبين بعد تسجيل نتائج المباريات.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            )
          else
            ...scorers.indexed.map((item) {
              final rank = item.$1 + 1;
              final scorer = item.$2;
              return _TopScorerRow(rank: rank, scorer: scorer);
            }),
        ],
      ),
    );
  }
}

class _TopScorerRow extends StatelessWidget {
  final int rank;
  final TournamentTopScorerEntry scorer;

  const _TopScorerRow({required this.rank, required this.scorer});

  @override
  Widget build(BuildContext context) {
    final actor = scorer.actor;
    final goals = scorer.goals;
    final isGuest = actor.kind == ParticipantRefKind.guestPlayer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Text(
              '$rank',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    actor.displayName,
                    style: AppTextStyles.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isGuest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Text(
                      'ضيف',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _goalCountLabel(goals),
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

String _goalCountLabel(int goals) {
  return goals == 1 ? '1 هدف' : '$goals أهداف';
}

class _InfoCard extends StatelessWidget {
  final Tournament tournament;

  const _InfoCard({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.lg),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        children: [
          _Row(
            icon: Icons.sports_soccer,
            label: 'حجم الفريق',
            value: '${tournament.teamSize.value}v${tournament.teamSize.value}',
          ),
          _Row(
            icon: Icons.format_list_bulleted,
            label: 'نوع الدورة',
            value: switch (tournament.format) {
              TournamentFormat.groupsOnly => 'مجموعات فقط',
              TournamentFormat.knockoutOnly => 'إقصاء مباشر',
              TournamentFormat.groupsThenKnockout => 'مجموعات + إقصاء',
            },
          ),
          _Row(
            icon: Icons.groups,
            label: 'عدد الفرق',
            value: '${tournament.maxTeams} فريق كحد أقصى',
          ),
          if (tournament.location != null)
            _Row(
              icon: Icons.location_on,
              label: 'الموقع',
              value: tournament.location!,
            ),
          _Row(
            icon: Icons.flag_circle_rounded,
            label: 'حالة البطولة',
            value: _tournamentStatusLabel(tournament.status),
          ),
          if (tournament.prizeDescription != null)
            _Row(
              icon: Icons.card_giftcard,
              label: 'الجائزة',
              value: tournament.prizeDescription!,
            ),
        ],
      ),
    );
  }
}

class _RegistrationProgress extends StatelessWidget {
  final Tournament tournament;

  const _RegistrationProgress({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('التسجيلات', style: AppTextStyles.titleMedium),
              const Spacer(),
              Text(
                '${tournament.teamCount}/${tournament.maxTeams}',
                style: AppTextStyles.ratingMedium.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: tournament.fillRate.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tournament.canRegister
                ? '${tournament.maxTeams - tournament.teamCount} مكان متبقي'
                : 'اكتملت الأماكن أو أُغلق التسجيل',
            style: AppTextStyles.labelSmall.copyWith(
              color: tournament.canRegister
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsSnapshot extends StatelessWidget {
  final Tournament tournament;
  final String championLabel;

  const _OperationsSnapshot({
    required this.tournament,
    required this.championLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حالة التشغيل', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.sm),
          _Row(
            icon: Icons.groups_2_rounded,
            label: 'قائمة المشاركين',
            value: tournament.participantListFinalizedAt == null
                ? 'غير مقفلة بعد'
                : 'تم قفلها',
          ),
          _Row(
            icon: Icons.grid_view_rounded,
            label: 'المجموعات',
            value: tournament.currentGroupStageId == null
                ? 'غير منشأة'
                : 'جاهزة',
          ),
          _Row(
            icon: Icons.account_tree_rounded,
            label: 'الإقصاء',
            value: tournament.currentKnockoutBracketId == null
                ? 'غير منشأ'
                : 'جاهز',
          ),
          if (tournament.winnerParticipantId != null)
            _Row(
              icon: Icons.emoji_events_rounded,
              label: 'البطل',
              value: championLabel.isEmpty
                  ? tournament.winnerParticipantId!
                  : championLabel,
            ),
          if (tournament.needsManualOpsMigration)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.sm),
              child: Text(
                'هذه البطولة تحتاج manual ops migration قبل التشغيل الكامل.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => Get.toNamed(
                  AppRoutes.tournamentParticipantsById(tournament.id),
                ),
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('المشاركون'),
              ),
              OutlinedButton.icon(
                onPressed: tournament.currentGroupStageId == null
                    ? null
                    : () => Get.toNamed(
                        AppRoutes.tournamentGroupsById(tournament.id),
                      ),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('المجموعات'),
              ),
              OutlinedButton.icon(
                onPressed:
                    tournament.currentGroupStageId == null &&
                        tournament.currentKnockoutBracketId == null
                    ? null
                    : () => Get.toNamed(
                        AppRoutes.tournamentFixturesById(tournament.id),
                      ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('المباريات'),
              ),
              OutlinedButton.icon(
                onPressed: tournament.currentGroupStageId == null
                    ? null
                    : () => Get.toNamed(
                        AppRoutes.tournamentStandingsById(tournament.id),
                      ),
                icon: const Icon(Icons.leaderboard_rounded),
                label: const Text('الترتيب'),
              ),
              OutlinedButton.icon(
                onPressed: tournament.currentKnockoutBracketId == null
                    ? null
                    : () => Get.toNamed(
                        AppRoutes.tournamentBracketById(tournament.id),
                      ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('الإقصاء'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FantasyLeagueButton extends StatelessWidget {
  final Tournament tournament;

  const _FantasyLeagueButton({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: El7reefButton(
        text: 'افتح فانتازي البطولة',
        icon: Icons.auto_awesome_rounded,
        onPressed: () {
          Get.toNamed(AppRoutes.fantasyLeaderboardForLeague(tournament.id));
        },
      ),
    );
  }
}

class _RegisterTeamButton extends StatelessWidget {
  final Tournament tournament;

  const _RegisterTeamButton({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('سجّل فريقك', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'افتح صفحة التسجيل لاختيار فريقك ومعرفة حالة طلبات البطولة الحالية.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          El7reefButton(
            text: 'فتح صفحة التسجيل',
            icon: Icons.app_registration_rounded,
            onPressed: () => Get.toNamed(
              AppRoutes.teamRegistrationForTournament(tournament.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerPanel extends StatelessWidget {
  final Tournament tournament;

  const _OrganizerPanel({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Text('لوحة التشغيل', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(
              AppRoutes.organizerDashboardForTournament(tournament.id),
            ),
            icon: const Icon(Icons.dashboard_customize_rounded),
            label: const Text('لوحة تشغيل البطولة'),
          ),
          const SizedBox(height: AppDimensions.sm),
          OutlinedButton.icon(
            onPressed: () => Get.toNamed(
              AppRoutes.teamRegistrationForTournament(tournament.id),
            ),
            icon: const Icon(Icons.app_registration_rounded),
            label: const Text('إدارة التسجيلات'),
          ),
          const SizedBox(height: AppDimensions.sm),
          if (FeatureFlags.organizerAdvancedOpsEnabled) ...[
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(
                AppRoutes.tournamentAssistantsById(tournament.id),
              ),
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('إدارة المساعدين'),
            ),
            const SizedBox(height: AppDimensions.sm),
          ],
          Text(
            'عمليات المراحل والتوليد والنشر والإغلاق أصبحت من dashboard التشغيلية فقط لتفادي status flips غير آمنة.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.labelMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

String _tournamentStatusLabel(TournamentStatus status) => switch (status) {
  TournamentStatus.upcoming => 'لم تبدأ بعد',
  TournamentStatus.registration => 'التسجيل مفتوح',
  TournamentStatus.groupStage => 'مرحلة المجموعات',
  TournamentStatus.transferWindow => 'نافذة التغييرات',
  TournamentStatus.knockoutStage => 'مرحلة الإقصاء',
  TournamentStatus.completed => 'مكتملة',
  TournamentStatus.cancelled => 'ملغاة',
};

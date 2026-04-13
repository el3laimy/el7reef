import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/tournament.dart';
import '../../../services/auth_service.dart';
import '../controllers/tournament_controller.dart';
import '../../../features/team/controllers/team_controller.dart';

/// شاشة تفاصيل الدورة — معلومات + جدول + زر التسجيل
class TournamentDetailScreen extends StatelessWidget {
  final Tournament tournament;
  const TournamentDetailScreen({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<TournamentController>();
    final authService = Get.find<AuthService>();
    final isOrganizer = tournament.organizerId == authService.currentUserId;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
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
                    // ── بطاقة المعلومات ──
                    _InfoCard(tournament: tournament)
                        .animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: AppDimensions.md),

                    // ── شريط تقدم التسجيل ──
                    _RegistrationProgress(tournament: tournament)
                        .animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: AppDimensions.md),

                    // ── جدول المجموعات ──
                    if (tournament.status == TournamentStatus.groupStage ||
                        tournament.status == TournamentStatus.knockoutStage ||
                        tournament.status == TournamentStatus.completed)
                      _StandingsPreview(tournament: tournament)
                          .animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: AppDimensions.md),

                    // ── أزرار التسجيل ──
                    if (!isOrganizer &&
                        tournament.status == TournamentStatus.registration)
                      _RegisterTeamButton(
                              tournament: tournament, ctrl: ctrl)
                          .animate().fadeIn(delay: 300.ms),

                    // ── أزرار المنظم ──
                    if (isOrganizer) ...[
                      _OrganizerPanel(tournament: tournament, ctrl: ctrl)
                          .animate().fadeIn(delay: 300.ms),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة معلومات الدورة ──
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
          _Row(icon: Icons.sports_soccer,
              label: 'حجم الفريق',
              value: '${tournament.teamSize.value}v${tournament.teamSize.value}'),
          _Row(icon: Icons.format_list_bulleted,
              label: 'نوع الدورة',
              value: _formatLabel(tournament.format)),
          _Row(icon: Icons.groups,
              label: 'عدد الفرق',
              value: '${tournament.maxTeams} فريق كحد أقصى'),
          if (tournament.location != null)
            _Row(icon: Icons.location_on,
                label: 'الموقع',
                value: tournament.location!),
          if (tournament.isFantasyEnabled)
            _Row(icon: Icons.auto_awesome,
                label: 'الفانتازي',
                value: 'مفعَّل ✅'),
          if (tournament.prizeDescription != null)
            _Row(icon: Icons.card_giftcard,
                label: 'الجائزة',
                value: tournament.prizeDescription!),
        ],
      ),
    );
  }

  String _formatLabel(TournamentFormat f) => switch (f) {
    TournamentFormat.groupsOnly => 'مجموعات فقط',
    TournamentFormat.knockoutOnly => 'إقصاء مباشر',
    TournamentFormat.groupsThenKnockout => 'مجموعات + إقصاء',
  };
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
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ── شريط تقدم التسجيل ──
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
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: tournament.fillRate.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tournament.canRegister
                ? '${tournament.maxTeams - tournament.teamCount} مكان متبقي'
                : 'اكتملت الأماكن',
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

// ── معاينة جدول المجموعات ──
class _StandingsPreview extends StatelessWidget {
  final Tournament tournament;
  const _StandingsPreview({required this.tournament});

  @override
  Widget build(BuildContext context) {
    // عرض مبسط للترتيب — سيُكتمل مع بيانات حقيقية
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('جدول الترتيب', style: AppTextStyles.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: Text('عرض الكل',
                    style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary)),
              ),
            ],
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 24),
                Expanded(
                    child: Text('الفريق',
                        style: AppTextStyles.labelSmall)),
                SizedBox(width: 28,
                    child: Text('ل', style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center)),
                SizedBox(width: 28,
                    child: Text('ف', style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center)),
                SizedBox(width: 28,
                    child: Text('ت', style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center)),
                SizedBox(width: 28,
                    child: Text('خ', style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center)),
                SizedBox(width: 36,
                    child: Text('نق', style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceBorder, height: 1),
          // Placeholder rows
          ...List.generate(
            tournament.teamCount.clamp(0, 4),
            (i) => _StandingRow(rank: i + 1,
                teamName: 'فريق ${i + 1}',
                played: 0, wins: 0, draws: 0, losses: 0, points: 0),
          ),
          if (tournament.teamCount == 0)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Center(
                child: Text('لم تبدأ المباريات بعد',
                    style: AppTextStyles.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int rank;
  final String teamName;
  final int played, wins, draws, losses, points;
  const _StandingRow({
    required this.rank, required this.teamName,
    required this.played, required this.wins,
    required this.draws, required this.losses, required this.points,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor = AppColors.textMuted;
    if (rank == 1) rankColor = AppColors.secondary;
    if (rank == 2) rankColor = AppColors.textMuted;
    if (rank == 3) rankColor = AppColors.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 24,
              child: Text('$rank',
                  style: AppTextStyles.labelMedium.copyWith(color: rankColor),
                  textAlign: TextAlign.center)),
          Expanded(child: Text(teamName, style: AppTextStyles.bodyMedium,
              overflow: TextOverflow.ellipsis)),
          SizedBox(width: 28, child: Text('$played',
              style: AppTextStyles.labelSmall, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('$wins',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
              textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('$draws',
              style: AppTextStyles.labelSmall, textAlign: TextAlign.center)),
          SizedBox(width: 28, child: Text('$losses',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
              textAlign: TextAlign.center)),
          SizedBox(width: 36, child: Text('$points',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ── زر تسجيل الفريق ──
class _RegisterTeamButton extends StatelessWidget {
  final Tournament tournament;
  final TournamentController ctrl;
  const _RegisterTeamButton({required this.tournament, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final teamCtrl = Get.find<TeamController>();
    return Obx(() {
      final myTeams = teamCtrl.myTeams;
      if (myTeams.isEmpty) {
        return GlassmorphicContainer(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusMd,
          child: Column(
            children: [
              const Text('👥', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text('عندك فريق؟ أنشئه الأول!',
                  style: AppTextStyles.bodyMedium),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('سجّل فريقك', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          ...myTeams.map((team) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: OutlinedButton.icon(
                  onPressed: tournament.canRegister &&
                          !tournament.registeredTeamIds.contains(team.id)
                      ? () => ctrl.registerTeam(tournament.id, team.id)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(tournament.registeredTeamIds.contains(team.id)
                      ? '${team.name} (مسجّل ✅)'
                      : team.name),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tournament.registeredTeamIds.contains(team.id)
                        ? AppColors.success
                        : AppColors.primary,
                    side: BorderSide(
                      color: tournament.registeredTeamIds.contains(team.id)
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
              )),
        ],
      );
    });
  }
}

// ── لوحة المنظم ──
class _OrganizerPanel extends StatelessWidget {
  final Tournament tournament;
  final TournamentController ctrl;
  const _OrganizerPanel({required this.tournament, required this.ctrl});

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
              const Icon(Icons.admin_panel_settings,
                  color: AppColors.secondary),
              const SizedBox(width: 8),
              Text('لوحة المنظم', style: AppTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          if (tournament.status == TournamentStatus.registration)
            El7reefButton(
              text: 'ابدأ المجموعات',
              icon: Icons.play_arrow_rounded,
              onPressed: () => ctrl.startGroupStage(tournament.id),
            ),

          if (tournament.status == TournamentStatus.groupStage) ...[
            El7reefButton(
              text: 'افتح نافذة التغيير',
              icon: Icons.swap_horiz_rounded,
              onPressed: () => ctrl.openTransferWindow(tournament.id),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ctrl.startKnockoutStage(tournament.id),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('ابدأ الإقصاء'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],

          if (tournament.status == TournamentStatus.knockoutStage)
            El7reefButton(
              text: 'أنهِ الدورة',
              icon: Icons.emoji_events_rounded,
              onPressed: () => ctrl.completeTournament(tournament.id),
            ),

          if (tournament.status == TournamentStatus.completed)
            Center(child: Text('🏆 الدورة منتهية',
                style: AppTextStyles.headlineMedium)),
        ],
      ),
    );
  }
}

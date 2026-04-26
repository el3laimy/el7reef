import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../domain/entities/match.dart';
import '../../team/controllers/team_controller.dart';
import '../controllers/match_controller.dart';
import '../controllers/challenge_controller.dart';
import '../widgets/challenge_card.dart';

/// شاشة اكتشاف المباريات المتاحة + إنشاء مباراة جديدة
class MatchDiscoverScreen extends GetView<MatchController> {
  const MatchDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/images/logo_icon.png', height: 28),
              const SizedBox(width: AppDimensions.sm),
              const Text('المباريات'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: () {
                controller.loadLiveMatches();
                controller.loadMyMatches();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'مبارياتي'),
              Tab(text: 'اكتشاف'),
              Tab(text: 'التحديات'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: const TabBarView(
            children: [_MyMatchesTab(), _DiscoverTab(), _ChallengesTab()],
          ),
        ),
      ),
    );
  }
}

// Global method or extension? Let's just use Get.bottomSheet directly where needed or fetch controller.
void showCreateMatchSheetGlobal() {
  final controller = Get.find<MatchController>();
  Get.bottomSheet(
    _CreateMatchSheet(controller: controller),
    isScrollControlled: true,
  );
}

class _MyMatchesTab extends GetView<MatchController> {
  const _MyMatchesTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.myMatches.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      if (controller.myMatches.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppDimensions.md),
              Text('ليس لديك أي مباريات قادمة', style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppDimensions.lg),
              El7reefButton(
                text: 'أنشئ مباراة جديدة',
                onPressed: showCreateMatchSheetGlobal,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadMyMatches,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          itemCount: controller.myMatches.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: _MatchCard(
                match: controller.myMatches[index],
                index: index,
                controller: controller,
              ),
            );
          },
        ),
      );
    });
  }
}

class _DiscoverTab extends GetView<MatchController> {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.liveMatches.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadLiveMatches,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.pagePadding),
                child: El7reefButton(
                  text: 'ابدأ مباراة جديدة',
                  icon: Icons.sports_soccer,
                  onPressed: showCreateMatchSheetGlobal,
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.pagePadding,
                ),
                child: Row(
                  children: [
                    Text('المباريات الجارية', style: AppTextStyles.titleLarge),
                    const Spacer(),
                    Text(
                      '${controller.liveMatches.length} مباراة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),
            if (controller.liveMatches.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'لا توجد مباريات جارية حالياً',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final match = controller.liveMatches[index];
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: AppDimensions.pagePadding,
                      right: AppDimensions.pagePadding,
                      bottom: AppDimensions.md,
                    ),
                    child: _MatchCard(
                      match: match,
                      index: index,
                      controller: controller,
                    ).animate().fadeIn(delay: (100 * index).ms),
                  );
                }, childCount: controller.liveMatches.length),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    });
  }
}

class _ChallengesTab extends GetView<ChallengeController> {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value &&
          controller.sentChallenges.isEmpty &&
          controller.receivedChallenges.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadChallenges,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            if (controller.receivedChallenges.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Text('تحديات واردة', style: AppTextStyles.titleLarge),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final challenge = controller.receivedChallenges[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.xs,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      isSentByMe: false,
                      otherPartyName: controller.getPlayerName(
                        challenge.challengerId,
                      ),
                      onAccept: () => controller.acceptChallenge(challenge),
                      onDecline: () =>
                          controller.declineChallenge(challenge.id),
                    ),
                  );
                }, childCount: controller.receivedChallenges.length),
              ),
            ],

            if (controller.sentChallenges.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePadding),
                  child: Text(
                    'تحديات أرسلتها',
                    style: AppTextStyles.titleLarge,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final challenge = controller.sentChallenges[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pagePadding,
                      vertical: AppDimensions.xs,
                    ),
                    child: ChallengeCard(
                      challenge: challenge,
                      isSentByMe: true,
                      otherPartyName: controller.getPlayerName(
                        challenge.challengedId,
                      ),
                      onCancel: () => controller.cancelChallenge(challenge.id),
                    ),
                  );
                }, childCount: controller.sentChallenges.length),
              ),
            ],

            if (controller.receivedChallenges.isEmpty &&
                controller.sentChallenges.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'لا توجد تحديات حالياً',
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      );
    });
  }
}

/// بطاقة المباراة
class _MatchCard extends StatelessWidget {
  final Match match;
  final int index;
  final MatchController controller;

  const _MatchCard({
    required this.match,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isOrganizer =
        match.organizerId == controller.authService.currentUserId;
    final canOpenMatchday =
        isOrganizer ||
        match.isOrganized ||
        match.teamAId != null ||
        match.teamBId != null;

    return GlassmorphicContainer(
          padding: const EdgeInsets.all(AppDimensions.md),
          borderRadius: AppDimensions.radiusLg,
          margin: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  _StatusBadge(status: match.status),
                  const Spacer(),
                  if (match.isGoldenRating)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusFull,
                        ),
                      ),
                      child: Text(
                        '⭐ ذهبي',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (match.isFrozen) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.lock,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppDimensions.md),

              // ── الفريقان ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('🔵', style: TextStyle(fontSize: 28)),
                        Text(
                          '${match.teamAPlayerIds.length} لاعب',
                          style: AppTextStyles.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (match.scoreTeamA != null && match.scoreTeamB != null)
                        Text(
                          '${match.scoreTeamA} - ${match.scoreTeamB}',
                          style: AppTextStyles.ratingMedium.copyWith(
                            fontSize: 24,
                          ),
                        )
                      else
                        Text('vs', style: AppTextStyles.headlineMedium),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('🔴', style: TextStyle(fontSize: 28)),
                        Text(
                          '${match.teamBPlayerIds.length} لاعب',
                          style: AppTextStyles.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.md),

              if (canOpenMatchday)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.matchDetailsById(match.id)),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('إدارة يوم المباراة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),

              // ── زر تصويت الجماهير (Fan Voting) ──
              if (match.status == MatchStatus.completed ||
                  match.status == MatchStatus.pendingReview ||
                  match.status == MatchStatus.settled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Get.toNamed(AppRoutes.mvpVoteForMatch(match.id)),
                    icon: const Icon(Icons.star_border_purple500, size: 18),
                    label: const Text('تصويت رجل المباراة (الجماهير)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                    ),
                  ),
                ),

              // ── أزرار المنظم ──
              if (isOrganizer &&
                  !match.isFrozen &&
                  match.status == MatchStatus.live)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.toNamed(
                          AppRoutes.scoreApprovalForMatch(match.id),
                        ),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('سجّل النتيجة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => controller.freezeMatch(match.id),
                      icon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'تجميد',
                    ),
                    IconButton(
                      onPressed: () =>
                          controller.activateGoldenRating(match.id),
                      icon: const Icon(
                        Icons.star_outline,
                        color: AppColors.secondary,
                      ),
                      tooltip: 'تقييم ذهبي',
                    ),
                  ],
                ),

              // ── زر إلغاء المباراة (للمنظم فقط) ──
              if (isOrganizer &&
                  match.tournamentId == null &&
                  !match.isFrozen &&
                  (match.status == MatchStatus.open ||
                      match.status == MatchStatus.full))
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancel(context),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('إلغاء المباراة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),

              if (isOrganizer &&
                  (match.status == MatchStatus.completed ||
                      match.status == MatchStatus.pendingReview))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => controller.approveScore(match.id),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      match.status == MatchStatus.pendingReview
                          ? 'اعتماد بعد المراجعة'
                          : 'اعتماد النتيجة',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        )
        .animate(delay: (80 * index).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1);
  }

  void _confirmCancel(BuildContext context) {
    final reasonController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('إلغاء المباراة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من إلغاء هذه المباراة؟ لن يتم حذف بيانات المباراة، لكنها لن تظهر كمباراة نشطة.',
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء اختياري',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              final reason = reasonController.text;
              Get.back();
              controller.cancelMatch(match.id, reason: reason);
            },
            child: const Text(
              'إلغاء المباراة',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge حالة المباراة
class _StatusBadge extends StatelessWidget {
  final MatchStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      MatchStatus.open => (AppColors.success, '🟢 مفتوحة'),
      MatchStatus.live => (AppColors.primary, '🔵 جارية'),
      MatchStatus.completed => (AppColors.secondary, '⏳ بانتظار الاعتماد'),
      MatchStatus.settled => (AppColors.textMuted, '✅ منتهية'),
      MatchStatus.pendingReview => (AppColors.warning, '🟠 قيد المراجعة'),
      MatchStatus.frozen => (AppColors.error, '🔒 مجمدة'),
      MatchStatus.full => (AppColors.accent, '🔴 مكتملة'),
      MatchStatus.cancelled => (AppColors.error, '❌ ملغاة'),
      _ => (AppColors.textMuted, '⏸ معلقة'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

/// Sheet إنشاء مباراة
class _CreateMatchSheet extends StatefulWidget {
  final MatchController controller;
  const _CreateMatchSheet({required this.controller});

  @override
  State<_CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<_CreateMatchSheet> {
  final _locationController = TextEditingController();
  final _selectedTeamSize = 5.obs;
  final RxBool _playAsTeam = false.obs;
  final RxnString _selectedTeamId = RxnString();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Try to find TeamController to fetch user's teams
    final hasTeamController = Get.isRegistered<TeamController>();
    final teamCtrl = hasTeamController ? Get.find<TeamController>() : null;

    return Container(
      padding:
          EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.lg,
          ).copyWith(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
          ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            Text('ابدأ مباراة جديدة ⚽', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'أنشئ المباراة وادعُ اللاعبين للانضمام',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── نوع المشاركة (فرد أم فريق) ──
            if (teamCtrl != null && teamCtrl.myTeams.isNotEmpty) ...[
              Text('كيف ستلعب هذه المباراة؟', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppDimensions.sm),
              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('كلاعب فردي (Pickup)')),
                        selected: !_playAsTeam.value,
                        onSelected: (val) {
                          if (val) {
                            _playAsTeam.value = false;
                            _selectedTeamId.value = null;
                          }
                        },
                        selectedColor: AppColors.primarySurface,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('باسم فريقي')),
                        selected: _playAsTeam.value,
                        onSelected: (val) {
                          if (val) {
                            _playAsTeam.value = true;
                            if (teamCtrl.myTeams.isNotEmpty) {
                              _selectedTeamId.value = teamCtrl.myTeams.first.id;
                            }
                          }
                        },
                        selectedColor: AppColors.primarySurface,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() {
                if (_playAsTeam.value && teamCtrl.myTeams.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.md),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'اختر فريقك',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTeamId.value,
                          isExpanded: true,
                          items: teamCtrl.myTeams.map((team) {
                            return DropdownMenuItem(
                              value: team.id,
                              child: Text(team.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            _selectedTeamId.value = val;
                          },
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: AppDimensions.md),
            ],

            // ── المكان ──
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'المكان (اختياري)',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // ── عدد اللاعبين ──
            Text('عدد اللاعبين لكل فريق', style: AppTextStyles.titleSmall),
            const SizedBox(height: AppDimensions.sm),
            Obx(
              () => Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: supportedPlayerCounts
                    .map((size) {
                      return ChoiceChip(
                        label: Text('${size}v$size'),
                        selected: _selectedTeamSize.value == size,
                        onSelected: (_) => _selectedTeamSize.value = size,
                        selectedColor: AppColors.primarySurface,
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),

            Obx(
              () => El7reefButton(
                text: 'إنشاء المباراة',
                icon: Icons.play_arrow_rounded,
                isLoading: widget.controller.isLoading.value,
                onPressed: () async {
                  final uid = widget.controller.authService.currentUserId;
                  if (uid == null) return;

                  // if playing as individual, add uid to teamAIds.
                  // if playing as team, teamAId is set, and uid is not strictly needed in teamAIds
                  // but we can add it anyway so the creator is part of the match.
                  final isTeam =
                      _playAsTeam.value && _selectedTeamId.value != null;

                  final matchId = await widget.controller.createMatch(
                    teamAIds: [uid],
                    teamBIds: [],
                    teamAId: isTeam ? _selectedTeamId.value : null,
                    location: _locationController.text.trim().isNotEmpty
                        ? _locationController.text.trim()
                        : null,
                    teamSize: _selectedTeamSize.value,
                  );
                  Get.back();
                  if (matchId != null) {
                    Get.toNamed('/match/lobby/$matchId');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/services/match_start_service.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/qr_code_widget.dart';
import '../../../domain/entities/player.dart';
import '../controllers/match_lobby_controller.dart';
import '../models/friendly_match_side_view.dart';
import '../widgets/invite_friends_sheet.dart';
import '../widgets/match_formation_section.dart';
import '../../social/controllers/friend_controller.dart';

/// شاشة لوبي المباراة — مركز العمليات الشامل (Match Dashboard)
class MatchLobbyScreen extends GetView<MatchLobbyController> {
  const MatchLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final match = controller.match.value;
            if (match == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      'لم يتم العثور على المباراة',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              );
            }

            final isOpen = match.status == MatchStatus.open;
            final isStartableStatus =
                match.status == MatchStatus.open ||
                match.status == MatchStatus.full;
            final readiness = controller.startReadiness.value;
            final sideA = _sideViewFor(controller.sideViews, 'A');
            final sideB = _sideViewFor(controller.sideViews, 'B');

            return RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.pagePadding),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'لوبي المباراة',
                                  style: AppTextStyles.headlineMedium,
                                ),
                                Text(
                                  '${controller.effectiveTeamSize}v${controller.effectiveTeamSize}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                                if (match.location != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        match.location!,
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (controller.isOrganizer)
                            IconButton(
                              onPressed: () => _showMatchSettings(context),
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.textPrimary,
                              ),
                              tooltip: 'إعدادات المباراة',
                            ),
                          _StatusChip(status: match.status),
                        ],
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                  ),

                  // ── Readiness Stepper ──
                  if (isStartableStatus && controller.isOrganizer)
                    SliverToBoxAdapter(
                      child: _ReadinessStepper(
                        readiness: readiness,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                    ),

                  // ── QR Code + رابط الدعوة ──
                  if (isOpen)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.all(AppDimensions.lg),
                          borderRadius: AppDimensions.radiusLg,
                          child: Column(
                            children: [
                              Text(
                                'ادعُ اللاعبين 📲',
                                style: AppTextStyles.titleLarge,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              QrCodeWidget(
                                data: controller.inviteLink,
                                label: 'امسح للانضمام',
                                sublabel: match.location,
                                size: 160,
                                showBorder: false,
                              ),
                              const SizedBox(height: AppDimensions.md),
                              // رابط الدعوة
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.md,
                                  vertical: AppDimensions.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        controller.inviteLink,
                                        style: AppTextStyles.labelSmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: controller.copyInviteLink,
                                      icon: const Icon(
                                        Icons.copy,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      tooltip: 'نسخ الرابط',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.lg),
                  ),

                  // ── فريق A (Collapsible) ──
                  SliverToBoxAdapter(
                    child: _CollapsibleTeamSection(
                      sideView: sideA,
                      players: controller.teamAPlayers,
                      side: 'A',
                      isOrganizer: controller.isOrganizer,
                      isOpen:
                          controller.isFriendlyMatchHost && isStartableStatus,
                      matchId: controller.matchId,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'A'),
                      onAdd: () {
                        Get.bottomSheet(
                          _RegisteredPlayerPickerSheet(
                            lobbyController: controller,
                            sideKey: 'A',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onInvite: () {
                        Get.bottomSheet(
                          InviteFriendsSheet(
                            lobbyController: controller,
                            side: 'A',
                          ),
                          isScrollControlled: true,
                        );
                      },
                    ).animate().fadeIn(delay: 300.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.md),
                  ),

                  // ── فريق B (Collapsible) ──
                  SliverToBoxAdapter(
                    child: _CollapsibleTeamSection(
                      sideView: sideB,
                      players: controller.teamBPlayers,
                      side: 'B',
                      isOrganizer: controller.isOrganizer,
                      isOpen:
                          controller.isFriendlyMatchHost && isStartableStatus,
                      matchId: controller.matchId,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'B'),
                      onAdd: () {
                        Get.bottomSheet(
                          _RegisteredPlayerPickerSheet(
                            lobbyController: controller,
                            sideKey: 'B',
                          ),
                          isScrollControlled: true,
                        );
                      },
                      onInvite: () {
                        Get.bottomSheet(
                          InviteFriendsSheet(
                            lobbyController: controller,
                            side: 'B',
                          ),
                          isScrollControlled: true,
                        );
                      },
                    ).animate().fadeIn(delay: 400.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),

                  // ── خطة اللعب (Pitch) ──
                  SliverToBoxAdapter(
                    child: MatchFormationSection(
                      controller: controller,
                    ).animate().fadeIn(delay: 500.ms),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),

                  // ── Sticky Start Action ──
                  if (controller.isOrganizer)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: Column(
                          children: [
                            if (isStartableStatus)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: readiness.canStart
                                      ? controller.startMatch
                                      : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(
                                    readiness.canStart
                                        ? 'ابدأ المباراة ⚽'
                                        : 'غير جاهز للبدء',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: readiness.canStart
                                        ? AppColors.success
                                        : AppColors.surfaceBorder,
                                    foregroundColor: readiness.canStart
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.md,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMd,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (isOpen) ...[
                              const SizedBox(height: AppDimensions.sm),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmCancel(context),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('إلغاء المباراة'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.md,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ).animate().fadeIn(delay: 500.ms),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppDimensions.xl),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('إلغاء المباراة'),
        content: const Text('هل أنت متأكد من إلغاء هذه المباراة؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('لا')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.cancelMatch();
            },
            child: const Text(
              'نعم، إلغاء',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchSettings(BuildContext context) {
    Get.bottomSheet(
      _MatchSettingsSheet(controller: controller),
      isScrollControlled: true,
    );
  }
}

FriendlyMatchSideView? _sideViewFor(
  Iterable<FriendlyMatchSideView> sides,
  String sideKey,
) {
  for (final side in sides) {
    if (side.sideKey == sideKey) return side;
  }
  return null;
}

/// ── Readiness Stepper ──
/// Shows why the match can't start yet, or confirms it's ready.
class _ReadinessStepper extends StatelessWidget {
  final MatchStartReadiness readiness;

  const _ReadinessStepper({required this.readiness});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  readiness.canStart
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: readiness.canStart
                      ? AppColors.success
                      : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  readiness.canStart ? 'جاهز للبدء ✅' : 'متطلبات البدء',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: readiness.canStart
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
            if (!readiness.canStart) ...[
              const SizedBox(height: AppDimensions.sm),
              ...readiness.blockedReasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 14,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppDimensions.xs),
                      Expanded(
                        child: Text(
                          reason,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ── Settings Sheet ──
class _MatchSettingsSheet extends StatelessWidget {
  final MatchLobbyController controller;

  const _MatchSettingsSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Obx(() {
          final match = controller.match.value;
          final isTournament = match?.tournamentId != null;
          final currentSize = controller.effectiveTeamSize;
          final canChange = controller.canChangeTeamSize;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إعدادات المباراة', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isTournament
                    ? 'حجم مباراة البطولة يتم تحديده من إعدادات البطولة/الجدول.'
                    : canChange
                    ? 'تغيير عدد اللاعبين يؤثر على الفريقين والتشكيلات المفتوحة.'
                    : 'لا يمكن تغيير عدد اللاعبين بعد بدء المباراة أو بعد قفل أي تشكيلة.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppDimensions.lg),
              Text('عدد اللاعبين لكل فريق', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: supportedPlayerCounts
                    .map((size) {
                      final selected = size == currentSize;
                      return ChoiceChip(
                        label: Text('${size}v$size'),
                        selected: selected,
                        onSelected: canChange && !selected
                            ? (_) => _confirmTeamSizeChange(size)
                            : null,
                        selectedColor: AppColors.primarySurface,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceBorder,
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: AppDimensions.lg),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('إغلاق'),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _confirmTeamSizeChange(int size) {
    Get.dialog(
      AlertDialog(
        title: const Text('تغيير حجم المباراة'),
        content: Text(
          'سيتم تغيير المباراة إلى ${size}v$size. هذا يؤثر على الفريقين، '
          'وقد ينقل لاعبين زائدين إلى البدلاء في التشكيلات المفتوحة. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              Get.back();
              final saved = await controller.updateTeamSize(size);
              if (saved) {
                Get.back();
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

/// ── Collapsible Team Section ──
class _CollapsibleTeamSection extends StatefulWidget {
  final FriendlyMatchSideView? sideView;
  final RxList<Player> players;
  final String side;
  final bool isOrganizer;
  final bool isOpen;
  final String matchId;
  final void Function(String playerId) onRemove;
  final VoidCallback onAdd;
  final VoidCallback onInvite;

  const _CollapsibleTeamSection({
    required this.sideView,
    required this.players,
    required this.side,
    required this.isOrganizer,
    required this.isOpen,
    required this.matchId,
    required this.onRemove,
    required this.onAdd,
    required this.onInvite,
  });

  @override
  State<_CollapsibleTeamSection> createState() =>
      _CollapsibleTeamSectionState();
}

class _CollapsibleTeamSectionState extends State<_CollapsibleTeamSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final sideView =
        widget.sideView ??
        FriendlyMatchSideView(
          sideKey: widget.side,
          displayName: 'فريق ${widget.side}',
          officialTeamId: null,
          playerIds: const [],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pagePadding,
      ),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sideView.displayName,
                          style: AppTextStyles.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      _SideBadge(isOfficial: sideView.isOfficialTeam),
                      const SizedBox(width: AppDimensions.sm),
                      Obx(
                        () => Text(
                          '${widget.players.length} لاعب',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0 : -0.25,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isOrganizer) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      'أنت منظم المباراة',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isOpen && widget.isOrganizer) ...[
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.xs,
                runSpacing: AppDimensions.xs,
                children: [
                  TextButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('أضف لاعب'),
                  ),
                  TextButton.icon(
                    onPressed: widget.onInvite,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('ادعُ صديق'),
                  ),
                  if (sideView.canOpenOfficialLineup)
                    TextButton.icon(
                      onPressed: () => Get.toNamed(
                        AppRoutes.teamLineupEditorForMatch(
                          matchId: widget.matchId,
                          teamId: sideView.officialTeamId!,
                        ),
                      ),
                      icon: const Icon(Icons.sports_soccer_rounded, size: 18),
                      label: const Text('التشكيلة'),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                        vertical: AppDimensions.xs,
                      ),
                      child: Text(
                        'التشكيلة المؤقتة ستتوفر قريبًا',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            AnimatedCrossFade(
              firstChild: _buildPlayerList(),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList() {
    return Obx(() {
      if (widget.players.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
          child: Center(
            child: Text(
              'لا يوجد لاعبين بعد',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          const SizedBox(height: AppDimensions.sm),
          ...widget.players.map(
            (player) => _PlayerTile(
              player: player,
              canRemove: widget.isOrganizer && widget.isOpen,
              onRemove: () => widget.onRemove(player.id),
            ),
          ),
        ],
      );
    });
  }
}

class _SideBadge extends StatelessWidget {
  final bool isOfficial;

  const _SideBadge({required this.isOfficial});

  @override
  Widget build(BuildContext context) {
    final color = isOfficial ? AppColors.primary : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isOfficial ? 'رسمي' : 'مؤقت',
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _RegisteredPlayerPickerSheet extends StatelessWidget {
  final MatchLobbyController lobbyController;
  final String sideKey;

  const _RegisteredPlayerPickerSheet({
    required this.lobbyController,
    required this.sideKey,
  });

  @override
  Widget build(BuildContext context) {
    final friendController = Get.find<FriendController>();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Column(
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
            Text(
              'أضف لاعبًا مسجلًا لفريق $sideKey',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'الإضافة هنا تخص هذه المباراة فقط ولا تعدّل عضوية أي فريق رسمي.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Expanded(
              child: Obx(() {
                if (friendController.isLoading.value &&
                    friendController.friends.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (friendController.friends.isEmpty) {
                  return Center(
                    child: Text(
                      'لا يوجد لديك أصدقاء بعد',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  );
                }

                final currentUserId = friendController.currentUserId;
                if (currentUserId == null || currentUserId.isEmpty) {
                  return Center(
                    child: Text(
                      'سجّل الدخول أولًا لإضافة لاعب مسجل.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: friendController.friends.length,
                  itemBuilder: (context, index) {
                    final friendship = friendController.friends[index];
                    final friendId = friendship.getOtherUserId(currentUserId);
                    final friendProfile =
                        friendController.friendProfiles[friendId];
                    if (friendProfile == null) {
                      return const SizedBox.shrink();
                    }

                    final inTeamA = lobbyController.teamAPlayers.any(
                      (player) => player.id == friendId,
                    );
                    final inTeamB = lobbyController.teamBPlayers.any(
                      (player) => player.id == friendId,
                    );
                    final isAlreadyInTarget = sideKey == 'A'
                        ? inTeamA
                        : inTeamB;
                    final isInOpposite = sideKey == 'A' ? inTeamB : inTeamA;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySurface,
                        backgroundImage: friendProfile.photoThumbUrl != null
                            ? NetworkImage(friendProfile.photoThumbUrl!)
                            : null,
                        child: friendProfile.photoThumbUrl == null
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      title: Text(
                        friendProfile.name,
                        style: AppTextStyles.titleMedium,
                      ),
                      subtitle: Text(
                        friendProfile.username == null
                            ? 'لاعب مسجل'
                            : '@${friendProfile.username}',
                        style: AppTextStyles.labelSmall,
                      ),
                      trailing: isAlreadyInTarget
                          ? Text(
                              'موجود',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.success,
                              ),
                            )
                          : isInOpposite
                          ? Text(
                              'في الفريق الآخر',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.warning,
                              ),
                            )
                          : TextButton(
                              onPressed: () =>
                                  lobbyController.addRegisteredPlayerToSide(
                                    playerId: friendId,
                                    sideKey: sideKey,
                                  ),
                              child: const Text('إضافة'),
                            ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── بطاقة لاعب ──
class _PlayerTile extends StatelessWidget {
  final Player player;
  final bool canRemove;
  final VoidCallback onRemove;

  const _PlayerTile({
    required this.player,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySurface,
            backgroundImage: player.photoThumbUrl != null
                ? NetworkImage(player.photoThumbUrl!)
                : null,
            child: player.photoThumbUrl == null
                ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(child: Text(player.name, style: AppTextStyles.bodyMedium)),
          if (canRemove)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline,
                size: 20,
                color: AppColors.error,
              ),
              tooltip: 'إزالة',
            ),
        ],
      ),
    );
  }
}

/// ── Badge حالة المباراة ──
class _StatusChip extends StatelessWidget {
  final MatchStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      MatchStatus.open => (AppColors.success, '🟢 مفتوحة'),
      MatchStatus.live => (AppColors.primary, '🔵 جارية'),
      MatchStatus.completed => (AppColors.secondary, '✅ منتهية'),
      MatchStatus.cancelled => (AppColors.error, '❌ ملغاة'),
      _ => (AppColors.textMuted, '⏸ أخرى'),
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

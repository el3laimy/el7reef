import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../core/widgets/qr_code_widget.dart';
import '../../../domain/entities/player.dart';
import '../controllers/match_lobby_controller.dart';
import '../widgets/invite_friends_sheet.dart';
import '../widgets/match_formation_section.dart';

/// شاشة لوبي المباراة — إدارة اللاعبين + QR + بدء المباراة
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

                  // ── فريق A ──
                  SliverToBoxAdapter(
                    child: _TeamSection(
                      title: '🔵 فريق A',
                      players: controller.teamAPlayers,
                      side: 'A',
                      isOrganizer: controller.isOrganizer,
                      isOpen: isOpen,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'A'),
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

                  // ── فريق B ──
                  SliverToBoxAdapter(
                    child: _TeamSection(
                      title: '🔴 فريق B',
                      players: controller.teamBPlayers,
                      side: 'B',
                      isOrganizer: controller.isOrganizer,
                      isOpen: isOpen,
                      onRemove: (playerId) =>
                          controller.removePlayer(playerId, 'B'),
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

                  // ── أزرار الإجراءات ──
                  if (controller.isOrganizer)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.pagePadding,
                        ),
                        child: Column(
                          children: [
                            if (isOpen)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: controller.startMatch,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('ابدأ المباراة ⚽'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
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

/// ── قسم الفريق ──
class _TeamSection extends StatelessWidget {
  final String title;
  final RxList<Player> players;
  final String side;
  final bool isOrganizer;
  final bool isOpen;
  final void Function(String playerId) onRemove;
  final VoidCallback onInvite;

  const _TeamSection({
    required this.title,
    required this.players,
    required this.side,
    required this.isOrganizer,
    required this.isOpen,
    required this.onRemove,
    required this.onInvite,
  });

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
                Text(title, style: AppTextStyles.titleLarge),
                const Spacer(),
                if (isOpen)
                  TextButton.icon(
                    onPressed: onInvite,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('دعوة'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                const SizedBox(width: AppDimensions.sm),
                Obx(
                  () => Text(
                    '${players.length} لاعب',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Obx(() {
              if (players.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.md,
                  ),
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
                children: players
                    .map(
                      (player) => _PlayerTile(
                        player: player,
                        canRemove: isOrganizer && isOpen,
                        onRemove: () => onRemove(player.id),
                      ),
                    )
                    .toList(),
              );
            }),
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

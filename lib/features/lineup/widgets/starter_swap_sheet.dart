import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';

class StarterSwapSheet extends StatelessWidget {
  final String title;
  final List<FormationSlot> slots;
  final Map<String, LineupPlayer> playersByKey;
  final ValueChanged<FormationSlot> onSlotSelected;

  const StarterSwapSheet({
    super.key,
    required this.title,
    required this.slots,
    required this.playersByKey,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final occupiedSlots = slots
        .where((slot) => slot.occupantKey != null)
        .where((slot) => playersByKey.containsKey(slot.occupantKey))
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(
            left: AppDimensions.pagePadding,
            right: AppDimensions.pagePadding,
            top: AppDimensions.lg,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimensions.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTextStyles.headlineSmall),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'اختار اللاعب الأساسي الذي تريد تبديله مع الاحتياطي المختار.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryTinted,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: occupiedSlots.isEmpty
                    ? const _EmptyStarterState()
                    : ListView.separated(
                        key: const ValueKey('starter-swap-list'),
                        shrinkWrap: true,
                        itemCount: occupiedSlots.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppDimensions.sm),
                        itemBuilder: (context, index) {
                          final slot = occupiedSlots[index];
                          final player = playersByKey[slot.occupantKey]!;
                          return _StarterSwapTile(
                            slot: slot,
                            player: player,
                            onTap: () => onSlotSelected(slot),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarterSwapTile extends StatelessWidget {
  final FormationSlot slot;
  final LineupPlayer player;
  final VoidCallback onTap;

  const _StarterSwapTile({
    required this.slot,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = lineupRoleColor(slot.role);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: ValueKey('starter-swap-slot-${slot.id}'),
        onTap: onTap,
        tileColor: AppColors.textPrimaryTinted.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          side: BorderSide(
            color: AppColors.textPrimaryTinted.withValues(alpha: 0.08),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.18),
          backgroundImage: (player.photoUrl ?? '').isEmpty
              ? null
              : NetworkImage(player.photoUrl!),
          child: (player.photoUrl ?? '').isEmpty
              ? Text(
                  lineupInitialsForPlayer(player),
                  style: AppTextStyles.titleMedium.copyWith(color: roleColor),
                )
              : null,
        ),
        title: Text(
          lineupDisplayName(player),
          style: AppTextStyles.titleMedium,
        ),
        subtitle: Text(
          [
            slot.role.arabicLabel,
            player.isTemporary
                ? 'مؤقت'
                : player.isGuest
                ? 'ضيف'
                : 'مسجل',
            player.preferredPosition,
          ].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
          style: AppTextStyles.labelSmall,
        ),
        trailing: const Icon(
          Icons.swap_horiz_rounded,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}

class _EmptyStarterState extends StatelessWidget {
  const _EmptyStarterState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.textPrimaryTinted.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(
        'لا يوجد لاعبون أساسيون حالياً',
        style: AppTextStyles.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

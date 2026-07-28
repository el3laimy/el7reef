import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_status.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/player.dart';

class PlayerTile extends StatelessWidget {
  final Player player;
  final bool canRemove;
  final VoidCallback onRemove;

  const PlayerTile({
    super.key,
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

class TemporaryPlayerTile extends StatelessWidget {
  final MatchSidePlayer player;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onInvite;

  const TemporaryPlayerTile({
    super.key,
    required this.player,
    this.canManage = false,
    this.onEdit,
    this.onRemove,
    this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (player.position != null && player.position!.isNotEmpty)
        player.position!,
      if (player.shirtNumber != null) '#${player.shirtNumber}',
      'مؤقت',
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.warning.withValues(alpha: 0.16),
            child: const Icon(
              Icons.badge_outlined,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  details,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              tooltip: 'خيارات',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit?.call();
                  case 'remove':
                    onRemove?.call();
                  case 'invite':
                    onInvite?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'invite',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('ادعُه يسجل'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final MatchStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      MatchStatus.open => (AppColors.actionPrimary, 'مفتوحة'),
      MatchStatus.live => (AppColors.tactical, 'مباشر'),
      MatchStatus.completed => (AppColors.success, 'معتمدة'),
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

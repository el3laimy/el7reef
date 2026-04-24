import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/lineup_types.dart';

class PlayerPickerSheet extends StatefulWidget {
  final String title;
  final List<LineupPlayer> players;
  final ValueChanged<LineupPlayer> onPlayerSelected;
  final VoidCallback? onAddGuest;
  final VoidCallback? onCancel;

  const PlayerPickerSheet({
    super.key,
    required this.title,
    required this.players,
    required this.onPlayerSelected,
    this.onAddGuest,
    this.onCancel,
  });

  @override
  State<PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<PlayerPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.players
        .where(
          (player) => player.name.toLowerCase().contains(query.toLowerCase()),
        )
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
            color: Color(0xFF07111F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        widget.onCancel ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم اللاعب',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: filtered.isEmpty
                    ? _EmptyPickerState(onAddGuest: widget.onAddGuest)
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppDimensions.sm),
                        itemBuilder: (context, index) {
                          final player = filtered[index];
                          return _PickerPlayerTile(
                            player: player,
                            onTap: () => widget.onPlayerSelected(player),
                          );
                        },
                      ),
              ),
              if (widget.onAddGuest != null) ...[
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onAddGuest,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('إضافة لاعب ضيف'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerPlayerTile extends StatelessWidget {
  final LineupPlayer player;
  final VoidCallback onTap;

  const _PickerPlayerTile({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      leading: CircleAvatar(
        backgroundColor: player.isGuest
            ? AppColors.warning.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.16),
        backgroundImage: (player.photoUrl ?? '').isEmpty
            ? null
            : NetworkImage(player.photoUrl!),
        child: (player.photoUrl ?? '').isEmpty
            ? Text(
                player.name.trim().isEmpty ? '?' : player.name.characters.first,
                style: AppTextStyles.titleMedium.copyWith(
                  color: player.isGuest
                      ? AppColors.warning
                      : AppColors.primaryLight,
                ),
              )
            : null,
      ),
      title: Text(player.name, style: AppTextStyles.titleMedium),
      subtitle: Text(
        [
          player.isGuest ? 'ضيف' : 'مسجل',
          player.preferredPosition,
          player.number == null ? null : '#${player.number}',
        ].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
        style: AppTextStyles.labelSmall,
      ),
      trailing: const Icon(Icons.add_circle_outline_rounded),
    );
  }
}

class _EmptyPickerState extends StatelessWidget {
  final VoidCallback? onAddGuest;

  const _EmptyPickerState({this.onAddGuest});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_off_rounded, color: AppColors.textMuted),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'لا يوجد لاعبون متاحون',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onAddGuest != null) ...[
            const SizedBox(height: AppDimensions.sm),
            TextButton.icon(
              onPressed: onAddGuest,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('أضف ضيفاً'),
            ),
          ],
        ],
      ),
    );
  }
}

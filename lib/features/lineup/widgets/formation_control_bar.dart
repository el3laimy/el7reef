import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/widgets/el7reef_glass_surface.dart';

class FormationControlBar extends StatelessWidget {
  final int playerCount;
  final String formationCode;
  final ValueChanged<int>? onPlayerCountChanged;
  final ValueChanged<String> onFormationChanged;
  final VoidCallback onReset;
  final VoidCallback? onShareMode;
  final bool isDirty;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final String? selectedPlayerName;
  final String? helperText;
  final bool enabled;
  final bool allowPlayerCountChange;

  const FormationControlBar({
    super.key,
    required this.playerCount,
    required this.formationCode,
    this.onPlayerCountChanged,
    required this.onFormationChanged,
    required this.onReset,
    this.onShareMode,
    this.isDirty = false,
    this.onSave,
    this.onCancel,
    this.selectedPlayerName,
    this.helperText,
    this.enabled = true,
    this.allowPlayerCountChange = false,
  });

  @override
  Widget build(BuildContext context) {
    return El7reefGlassSurface(
      role: El7reefGlassRole.floatingToolbar,
      tone: El7reefGlassTone.action,
      padding: const EdgeInsets.all(AppDimensions.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: allowPlayerCountChange && onPlayerCountChanged != null
                    ? _MenuChip<int>(
                        key: const ValueKey('squad-player-count-menu'),
                        icon: Icons.groups_2_rounded,
                        label: '${playerCount}v$playerCount',
                        enabled: enabled,
                        values: supportedPlayerCounts,
                        selectedValue: playerCount,
                        itemLabel: (count) => '$count لاعبين • ${count}v$count',
                        onSelected: onPlayerCountChanged!,
                      )
                    : _StaticControlChip(
                        icon: Icons.groups_2_rounded,
                        label: '${playerCount}v$playerCount',
                      ),
              ),
              const SizedBox(width: AppDimensions.xs),
              Expanded(
                flex: 5,
                child: _MenuChip<String>(
                  key: const ValueKey('squad-formation-menu'),
                  icon: Icons.grid_view_rounded,
                  label: formationCode,
                  enabled: enabled,
                  values: getAvailableFormations(playerCount),
                  selectedValue: formationCode,
                  itemLabel: (code) => '$code • ${formationStyleLabel(code)}',
                  onSelected: onFormationChanged,
                ),
              ),
              const SizedBox(width: AppDimensions.xs),
              _IconControlButton(
                icon: Icons.refresh_rounded,
                tooltip: 'إعادة ترتيب الخطة',
                enabled: enabled,
                onPressed: onReset,
              ),
              if (onShareMode != null) ...[
                const SizedBox(width: AppDimensions.xs),
                _IconControlButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'مشاركة التشكيلة',
                  enabled: true,
                  onPressed: onShareMode!,
                ),
              ],
            ],
          ),
          if (isDirty && onSave != null) ...[
            const SizedBox(height: AppDimensions.sm),
            _DirtyActionsRow(
              enabled: enabled,
              onSave: onSave!,
              onCancel: onCancel,
            ),
          ],
          if ((selectedPlayerName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app_rounded,
                    size: 17,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'مختار: ${selectedPlayerName!.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'اختر خانة للنقل أو التبديل',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondaryTinted,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if ((helperText ?? '').trim().isNotEmpty ||
              (!isDirty && onSave != null)) ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                if (!isDirty && onSave != null) ...[
                  Container(
                    key: const ValueKey('squad-tactics-saved'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.34),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'محفوظة',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                ] else ...[
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                ],
                Expanded(
                  child: Text(
                    (helperText ?? '').trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryTinted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DirtyActionsRow extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSave;
  final VoidCallback? onCancel;

  const _DirtyActionsRow({
    required this.enabled,
    required this.onSave,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('squad-tactics-dirty-actions'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.xs),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_note_rounded,
            size: 19,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppDimensions.xs),
          Expanded(
            child: Text(
              'تعديلات غير محفوظة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          if (onCancel != null) ...[
            _IconControlButton(
              icon: Icons.close_rounded,
              tooltip: 'إلغاء تعديلات التشكيلة',
              foregroundColor: AppColors.error,
              enabled: enabled,
              onPressed: onCancel!,
            ),
            const SizedBox(width: AppDimensions.xs),
          ],
          FilledButton.icon(
            key: const ValueKey('squad-tactics-save'),
            onPressed: enabled ? onSave : null,
            icon: const Icon(Icons.save_rounded, size: 17),
            label: const Text('حفظ'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              minimumSize: const Size(82, 38),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final List<T> values;
  final T selectedValue;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  const _MenuChip({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.values,
    required this.selectedValue,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      enabled: enabled,
      color: AppColors.surface,
      onSelected: onSelected,
      itemBuilder: (context) => values
          .map(
            (value) => PopupMenuItem<T>(
              value: value,
              child: Row(
                children: [
                  Icon(
                    value == selectedValue
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: value == selectedValue
                        ? AppColors.primaryLight
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      itemLabel(value),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: _ControlButtonSurface(
        icon: icon,
        label: label,
        trailingIcon: Icons.keyboard_arrow_down_rounded,
        enabled: enabled,
      ),
    );
  }
}

class _IconControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  const _IconControlButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 42, height: 38),
      style: IconButton.styleFrom(
        foregroundColor: foregroundColor ?? AppColors.primaryLight,
        backgroundColor: AppColors.surfaceBorder,
        disabledForegroundColor: AppColors.textMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          side: BorderSide(
            color: (foregroundColor ?? AppColors.primary).withValues(
              alpha: 0.28,
            ),
          ),
        ),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _StaticControlChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StaticControlChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return _ControlButtonSurface(icon: icon, label: label, enabled: true);
  }
}

class _ControlButtonSurface extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailingIcon;
  final bool enabled;

  const _ControlButtonSurface({
    required this.icon,
    required this.label,
    this.trailingIcon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? AppColors.textPrimary : AppColors.textMuted;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceBorder : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, color: foreground, size: 17),
          ],
        ],
      ),
    );
  }
}

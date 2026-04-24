import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/lineup/formation_library.dart';

class FormationControlBar extends StatelessWidget {
  final int playerCount;
  final String formationCode;
  final ValueChanged<int>? onPlayerCountChanged;
  final ValueChanged<String> onFormationChanged;
  final VoidCallback onReset;
  final VoidCallback? onShareMode;
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
    this.enabled = true,
    this.allowPlayerCountChange = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: const Color(0xFF101A28).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (allowPlayerCountChange && onPlayerCountChanged != null)
              _MenuChip<int>(
                icon: Icons.groups_2_rounded,
                label: '${playerCount}v$playerCount',
                enabled: enabled,
                values: supportedPlayerCounts,
                selectedValue: playerCount,
                itemLabel: (count) => '${count}v$count',
                onSelected: onPlayerCountChanged!,
              )
            else
              _StaticControlChip(
                icon: Icons.groups_2_rounded,
                label: '${playerCount}v$playerCount',
              ),
            const SizedBox(width: AppDimensions.sm),
            _MenuChip<String>(
              icon: Icons.grid_view_rounded,
              label: formationCode,
              enabled: enabled,
              values: getAvailableFormations(playerCount),
              selectedValue: formationCode,
              itemLabel: (code) => '$code - ${formationStyleLabel(code)}',
              onSelected: onFormationChanged,
            ),
            const SizedBox(width: AppDimensions.sm),
            _ControlButton(
              icon: Icons.refresh_rounded,
              label: 'إعادة ترتيب',
              enabled: enabled,
              onPressed: onReset,
            ),
            if (onShareMode != null) ...[
              const SizedBox(width: AppDimensions.sm),
              _ControlButton(
                icon: Icons.ios_share_rounded,
                label: 'المشاركة',
                enabled: true,
                onPressed: onShareMode!,
              ),
            ],
          ],
        ),
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
      color: const Color(0xFF162235),
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
                  Text(itemLabel(value), style: AppTextStyles.bodyMedium),
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

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: _ControlButtonSurface(icon: icon, label: label, enabled: enabled),
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
        color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
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

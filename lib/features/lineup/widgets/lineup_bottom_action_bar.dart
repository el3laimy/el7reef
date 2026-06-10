import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';

class LineupBottomActionBar extends StatelessWidget {
  final VoidCallback? onManageTeam;
  final VoidCallback? onSave;
  final VoidCallback? onStartMatch;
  final VoidCallback? onMore;
  final bool isSaving;
  final bool isStarting;
  final bool canStart;

  const LineupBottomActionBar({
    super.key,
    this.onManageTeam,
    this.onSave,
    this.onStartMatch,
    this.onMore,
    this.isSaving = false,
    this.isStarting = false,
    this.canStart = true,
  });

  @override
  Widget build(BuildContext context) {
    final saveOnlyMode = onStartMatch == null;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          if (onManageTeam != null) ...[
            _ActionTile(
              icon: Icons.groups_2_rounded,
              label: 'الفريق',
              onPressed: onManageTeam,
            ),
            const SizedBox(width: AppDimensions.sm),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: El7reefButton(
                text: saveOnlyMode ? 'حفظ التشكيلة' : 'بدء المباراة',
                icon: saveOnlyMode ? Icons.save_outlined : Icons.play_arrow_rounded,
                isLoading: saveOnlyMode ? isSaving : isStarting,
                onPressed: saveOnlyMode
                    ? (isSaving ? null : onSave)
                    : (canStart && !isStarting ? onStartMatch : null),
              ),
            ),
          ),
          if (!saveOnlyMode) ...[
            const SizedBox(width: AppDimensions.sm),
            _ActionTile(
              icon: Icons.save_outlined,
              label: 'حفظ',
              loading: isSaving,
              onPressed: onSave,
            ),
          ],
          if (onMore != null) ...[
            const SizedBox(width: AppDimensions.sm),
            _ActionTile(
              icon: Icons.more_horiz_rounded,
              label: 'المزيد',
              onPressed: onMore,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onPressed,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        width: 66,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: AppColors.textSecondary, size: 19),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/el7reef_state_card.dart';
import '../../../core/widgets/el7reef_surface.dart';

class TournamentStageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Future<void> Function()? onRefresh;

  const TournamentStageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final stageIcon = switch (title) {
      'دور المجموعات' => Icons.grid_view_rounded,
      'ترتيب البطولة' => Icons.leaderboard_rounded,
      'الأدوار الإقصائية' => Icons.account_tree_rounded,
      _ => Icons.emoji_events_outlined,
    };
    final stageColor = title == 'الأدوار الإقصائية'
        ? AppColors.accent
        : AppColors.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(stageIcon, color: stageColor, size: 19),
              ),
              const SizedBox(width: AppDimensions.sm),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: stageColor.withValues(alpha: 0.28),
            ),
          ),
          actions: [
            if (onRefresh != null)
              Semantics(
                button: true,
                label: 'تحديث البيانات',
                child: IconButton(
                  tooltip: 'تحديث',
                  constraints: const BoxConstraints.tightFor(
                    width: AppDimensions.buttonHeightMd,
                    height: AppDimensions.buttonHeightMd,
                  ),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
          ],
        ),
        body: ColoredBox(
          color: AppColors.backgroundDeep,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentStageStateView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionLoading;

  const TournamentStageStateView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.color = AppColors.primary,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: El7reefStateCard(
          title: title,
          message: message,
          icon: icon,
          color: color,
          action: actionLabel == null
              ? null
              : El7reefButton(
                  text: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
                  isLoading: actionLoading,
                ),
        ),
      ),
    );
  }
}

class TournamentStageDataNotice extends StatelessWidget {
  final bool isError;
  final VoidCallback? onRetry;

  const TournamentStageDataNotice.refreshing({super.key})
    : isError = false,
      onRetry = null;

  const TournamentStageDataNotice.cachedError({
    super.key,
    required this.onRetry,
  }) : isError = true;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.warning : AppColors.info;
    return Semantics(
      liveRegion: true,
      label: isError
          ? 'تعذر تحديث البيانات. يتم عرض آخر نسخة متاحة.'
          : 'جارٍ تحديث البيانات. يتم عرض آخر نسخة متاحة.',
      child: El7reefSurface(
        key: ValueKey(isError ? 'cached-error-notice' : 'refreshing-notice'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.md,
          AppDimensions.sm,
          AppDimensions.sm,
          AppDimensions.sm,
        ),
        color: color.withValues(alpha: 0.10),
        borderColor: color.withValues(alpha: 0.30),
        child: Row(
          children: [
            Icon(
              isError ? Icons.cloud_off_rounded : Icons.sync_rounded,
              color: color,
              size: AppDimensions.iconMd,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                isError
                    ? 'نعرض آخر بيانات متاحة، تعذر جلب التحديث.'
                    : 'نعرض البيانات الحالية أثناء جلب التحديث.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimaryTinted,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppDimensions.buttonHeightMd,
                    AppDimensions.buttonHeightMd,
                  ),
                ),
                child: const Text('حاول ثانية'),
              ),
          ],
        ),
      ),
    );
  }
}

class TournamentStageSkeleton extends StatelessWidget {
  final int rows;

  const TournamentStageSkeleton({super.key, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ تحميل بيانات المرحلة',
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const _SkeletonBlock(height: 84),
            const SizedBox(height: AppDimensions.md),
            const _SkeletonBlock(height: 48),
            const SizedBox(height: AppDimensions.md),
            ...List<Widget>.generate(
              rows,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: AppDimensions.sm),
                child: _SkeletonBlock(height: 64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;

  const _SkeletonBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
    );
  }
}

class TournamentGroupSelector extends StatelessWidget {
  final List<TournamentGroupSelectorItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const TournamentGroupSelector({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'اختيار المجموعة',
      child: SizedBox(
        height: AppDimensions.buttonHeightMd,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.sm),
          itemBuilder: (context, index) {
            final selectorItem = items[index];
            final selected = selectorItem.id == selectedId;
            return Semantics(
              button: true,
              selected: selected,
              label: selectorItem.label,
              child: ChoiceChip(
                key: ValueKey('group-selector-${selectorItem.id}'),
                label: Text(selectorItem.label),
                avatar: selectorItem.trailingCount == null
                    ? null
                    : CircleAvatar(
                        radius: 11,
                        backgroundColor: selected
                            ? AppColors.textOnPrimary.withValues(alpha: 0.14)
                            : AppColors.surfaceRaised,
                        child: Text(
                          '${selectorItem.trailingCount}',
                          textDirection: TextDirection.ltr,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: selected
                                ? AppColors.textOnPrimary
                                : AppColors.textSecondaryTinted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                selected: selected,
                onSelected: (_) => onSelected(selectorItem.id),
                showCheckmark: false,
                labelStyle: AppTextStyles.labelLarge.copyWith(
                  color: selected
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimaryTinted,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceBorderStrong,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TournamentGroupSelectorItem {
  final String id;
  final String label;
  final int? trailingCount;

  const TournamentGroupSelectorItem({
    required this.id,
    required this.label,
    this.trailingCount,
  });
}

class TournamentStageSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const TournamentStageSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryTinted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppDimensions.sm),
          trailing!,
        ],
      ],
    );
  }
}

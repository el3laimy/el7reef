import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/tournament_enums.dart';

class TournamentVisualSpec {
  final String statusLabel;
  final String stageLabel;
  final IconData icon;
  final Color accent;
  final int stageIndex;

  const TournamentVisualSpec({
    required this.statusLabel,
    required this.stageLabel,
    required this.icon,
    required this.accent,
    required this.stageIndex,
  });
}

TournamentVisualSpec tournamentVisualSpec(TournamentStatus status) {
  return switch (status) {
    TournamentStatus.upcoming => const TournamentVisualSpec(
      statusLabel: 'تستعد للانطلاق',
      stageLabel: 'التجهيز',
      icon: Icons.flag_outlined,
      accent: AppColors.textSecondary,
      stageIndex: 0,
    ),
    TournamentStatus.registration => const TournamentVisualSpec(
      statusLabel: 'التسجيل مفتوح',
      stageLabel: 'التسجيل',
      icon: Icons.how_to_reg_rounded,
      accent: AppColors.primary,
      stageIndex: 0,
    ),
    TournamentStatus.groupStage => const TournamentVisualSpec(
      statusLabel: 'دور المجموعات',
      stageLabel: 'المجموعات',
      icon: Icons.grid_view_rounded,
      accent: AppColors.primary,
      stageIndex: 1,
    ),
    TournamentStatus.transferWindow => const TournamentVisualSpec(
      statusLabel: 'استراحة ما قبل الإقصاء',
      stageLabel: 'الانتقال',
      icon: Icons.sync_alt_rounded,
      accent: AppColors.info,
      stageIndex: 1,
    ),
    TournamentStatus.knockoutStage => const TournamentVisualSpec(
      statusLabel: 'الأدوار الإقصائية',
      stageLabel: 'الإقصائيات',
      icon: Icons.account_tree_rounded,
      accent: AppColors.accent,
      stageIndex: 2,
    ),
    TournamentStatus.completed => const TournamentVisualSpec(
      statusLabel: 'بطولة مكتملة',
      stageLabel: 'البطل',
      icon: Icons.emoji_events_rounded,
      accent: AppColors.secondary,
      stageIndex: 3,
    ),
    TournamentStatus.cancelled => const TournamentVisualSpec(
      statusLabel: 'البطولة ملغاة',
      stageLabel: 'متوقفة',
      icon: Icons.block_rounded,
      accent: AppColors.error,
      stageIndex: 0,
    ),
  };
}

String tournamentFormatLabel(TournamentFormat format) {
  return switch (format) {
    TournamentFormat.groupsOnly => 'دوري مجموعات',
    TournamentFormat.knockoutOnly => 'إقصاء مباشر',
    TournamentFormat.groupsThenKnockout => 'مجموعات ثم إقصائيات',
  };
}

/// خطوط ملعب وظيفية تمنح أسطح البطولة شخصية واحدة بلا صور أو blur.
class TournamentFieldPattern extends StatelessWidget {
  final Color color;
  final Widget child;

  const TournamentFieldPattern({
    super.key,
    required this.child,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TournamentFieldPainter(color: color),
      child: child,
    );
  }
}

class TournamentStageRail extends StatelessWidget {
  static const _labels = ['التسجيل', 'المجموعات', 'الإقصاء', 'البطل'];

  final int activeIndex;
  final Color accent;
  final String semanticsLabel;

  const TournamentStageRail({
    super.key,
    required this.activeIndex,
    required this.accent,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = activeIndex.clamp(0, _labels.length - 1);

    return Semantics(
      label: 'مرحلة البطولة الحالية: $semanticsLabel',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: List.generate(_labels.length * 2 - 1, (index) {
                if (index.isOdd) {
                  final segmentIndex = index ~/ 2;
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: segmentIndex < safeIndex
                          ? accent.withValues(alpha: 0.65)
                          : AppColors.surfaceBorderStrong,
                    ),
                  );
                }
                final stageIndex = index ~/ 2;
                final reached = stageIndex <= safeIndex;
                final current = stageIndex == safeIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutQuart,
                  width: current ? 16 : 10,
                  height: current ? 16 : 10,
                  decoration: BoxDecoration(
                    color: reached ? accent : AppColors.surfaceBorderStrong,
                    shape: BoxShape.circle,
                    border: current
                        ? Border.all(
                            color: AppColors.textPrimaryTinted,
                            width: 2,
                          )
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppDimensions.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _labels[safeIndex],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${safeIndex + 1}/${_labels.length}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentStatusPill extends StatelessWidget {
  final TournamentVisualSpec spec;

  const TournamentStatusPill({super.key, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: spec.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: spec.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 15, color: spec.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              spec.statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: spec.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentFieldPainter extends CustomPainter {
  final Color color;

  const _TournamentFieldPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final inset = size.shortestSide * 0.07;
    final field = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(18)),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, field.top),
      Offset(size.width / 2, field.bottom),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.16,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2.4,
      Paint()..color = color.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _TournamentFieldPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

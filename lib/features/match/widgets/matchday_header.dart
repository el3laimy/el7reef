import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../../../core/enums/match_status.dart';
import '../controllers/matchday_controller.dart';

/// رأس المباراة الاحترافي — مستوحى من البث التلفزيوني
class MatchdayHeader extends StatelessWidget {
  final MatchdayController controller;
  const MatchdayHeader({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final match = controller.match.value;
    final tournament = controller.tournament.value;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2137), Color(0xFF1C2E45)],
        ),
        border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tournament name
          if (tournament != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 14,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tournament.name,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'مباراة ودية',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),

          const SizedBox(height: AppDimensions.md),

          // Score Board
          Row(
            children: [
              // Team A
              Expanded(
                child: Column(
                  children: [
                    _TeamBadge(label: 'A', color: AppColors.accent),
                    const SizedBox(height: 6),
                    Text(
                      controller.sideADisplayName.value,
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Score
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusColor(match?.status).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${match?.scoreTeamA ?? 0}  —  ${match?.scoreTeamB ?? 0}',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),

              // Team B
              Expanded(
                child: Column(
                  children: [
                    _TeamBadge(label: 'B', color: AppColors.error),
                    const SizedBox(height: 6),
                    Text(
                      controller.sideBDisplayName.value,
                      style: AppTextStyles.labelMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.md),

          // Meta chips row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _HeaderChip(
                icon: _statusIcon(match?.status),
                label: _statusLabel(match?.status),
                color: _statusColor(match?.status),
              ),
              if (match?.location != null && match!.location!.isNotEmpty)
                _HeaderChip(
                  icon: Icons.location_on_outlined,
                  label: match.location!,
                  color: AppColors.textMuted,
                ),
            ],
          ),

          // Record Score Button for Live matches only.
          if (match != null && match.status == MatchStatus.live) ...[
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.toNamed(AppRoutes.scoreApprovalForMatch(match.id));
                },
                icon: const Icon(Icons.sports),
                label: const Text('تسجيل وإنهاء المباراة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(MatchStatus? status) => switch (status) {
    MatchStatus.live => AppColors.success,
    MatchStatus.completed || MatchStatus.settled => AppColors.accent,
    MatchStatus.open || MatchStatus.full => AppColors.warning,
    _ => AppColors.textMuted,
  };

  IconData _statusIcon(MatchStatus? status) => switch (status) {
    MatchStatus.live => Icons.circle,
    MatchStatus.completed || MatchStatus.settled => Icons.check_circle_outline,
    _ => Icons.schedule_rounded,
  };

  String _statusLabel(MatchStatus? status) => switch (status) {
    MatchStatus.open => 'مفتوحة',
    MatchStatus.full => 'مكتملة',
    MatchStatus.live => 'جارية الآن',
    MatchStatus.completed => 'منتهية',
    MatchStatus.pendingReview => 'بانتظار المراجعة',
    MatchStatus.ratingWindow => 'نافذة التقييم',
    MatchStatus.settled => 'مقفلة',
    MatchStatus.frozen => 'مجمّدة',
    MatchStatus.cancelled => 'ملغاة',
    _ => 'غير معروفة',
  };
}

class _TeamBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TeamBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.6)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// شريط الإحصائيات السريع
class MatchdayQuickStats extends StatelessWidget {
  final MatchdayController controller;
  const MatchdayQuickStats({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final presentCount = controller.attendanceDrafts.values
        .where(
          (s) =>
              s == MatchAttendanceStatus.present ||
              s == MatchAttendanceStatus.late,
        )
        .length;
    final absentCount = controller.attendanceDrafts.values
        .where((s) => s == MatchAttendanceStatus.absent)
        .length;
    final starterCount = controller.lineupDrafts.values
        .where((v) => v == MatchdayLineupSlot.starter.name)
        .length;
    final subCount = controller.sideSubstitutions.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          _StatItem(
            value: '$presentCount',
            label: 'حاضر',
            color: AppColors.success,
          ),
          _divider(),
          _StatItem(
            value: '$absentCount',
            label: 'غائب',
            color: AppColors.error,
          ),
          _divider(),
          _StatItem(
            value: '$starterCount',
            label: 'أساسي',
            color: AppColors.accent,
          ),
          _divider(),
          _StatItem(
            value: '$subCount',
            label: 'تبديل',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 30, color: AppColors.surfaceBorder);
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// مؤشر التقدم — Stepper
class MatchdayProgressStepper extends StatelessWidget {
  final MatchdayController controller;
  const MatchdayProgressStepper({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasCheckIn = controller.activeCheckIn.value != null;
    final hasSnapshot = controller.activeSnapshot.value != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          _StepDot(done: hasCheckIn, active: !hasCheckIn, label: 'الحضور'),
          Expanded(child: _StepLine(done: hasCheckIn)),
          _StepDot(
            done: hasSnapshot,
            active: hasCheckIn && !hasSnapshot,
            label: 'التشكيل',
          ),
          Expanded(child: _StepLine(done: hasSnapshot)),
          _StepDot(done: false, active: hasSnapshot, label: 'التبديلات'),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool done;
  final bool active;
  final String label;
  const _StepDot({
    required this.done,
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.success
        : active
        ? AppColors.accent
        : AppColors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : active
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: done ? AppColors.success : AppColors.surfaceBorder,
    );
  }
}

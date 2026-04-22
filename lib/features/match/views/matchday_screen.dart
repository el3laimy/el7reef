import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/enums/match_attendance_status.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../controllers/matchday_controller.dart';
import '../widgets/matchday_header.dart';

class MatchdayScreen extends GetView<MatchdayController> {
  const MatchdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('يوم المباراة'),
        actions: [
          IconButton(
            onPressed: controller.loadMatchday,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Obx(() {
          if (controller.isLoading.value && controller.match.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (controller.errorMessage.value.isNotEmpty &&
              controller.match.value == null) {
            return _ErrorState(
              message: controller.errorMessage.value,
              onRetry: controller.loadMatchday,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadMatchday,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePadding),
              children: [
                MatchdayHeader(controller: controller),
                const SizedBox(height: AppDimensions.md),
                if (controller.selectedSide != null) ...[
                  MatchdayQuickStats(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  MatchdayProgressStepper(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  _SideSelector(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  _AttendanceSection(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  _LineupSection(controller: controller),
                  const SizedBox(height: AppDimensions.md),
                  _SubstitutionSection(controller: controller),
                ] else ...[
                  _SideSelector(controller: controller),
                ],
                const SizedBox(height: AppDimensions.xl),
              ],
            ),
          );
        }),
      ),
    );
  }
}


class _SideSelector extends StatelessWidget {
  final MatchdayController controller;

  const _SideSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.managedSides.isEmpty) {
      return _NoManagedSideCard(controller: controller);
    }

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأطراف القابلة للإدارة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.managedSides
                .map(
                  (side) => ChoiceChip(
                    label: Text(side.label),
                    selected: controller.selectedSideKey.value == side.key,
                    onSelected: (_) => controller.selectSide(side.key),
                    selectedColor: AppColors.primarySurface,
                    labelStyle: TextStyle(
                      color: controller.selectedSideKey.value == side.key
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}


class _AttendanceSection extends StatelessWidget {
  final MatchdayController controller;

  const _AttendanceSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final locked = controller.isLineupLocked;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Check-in والحضور', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            locked
                ? 'تم تثبيت الحضور بعد قفل التشكيل. يمكنك مراجعة الحالة الحالية فقط.'
                : 'حدّد حالة كل لاعب قبل قفل التشكيل.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          ...controller.participants.map(
            (participant) => _ParticipantAttendanceTile(
              controller: controller,
              participant: participant,
              enabled: !locked && !controller.isSubmitting.value,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: locked || controller.isSubmitting.value
                  ? null
                  : controller.submitCheckIn,
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              label: Text(
                controller.activeCheckIn.value == null
                    ? 'تنفيذ check-in'
                    : 'تحديث check-in',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupSection extends StatelessWidget {
  final MatchdayController controller;

  const _LineupSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.activeSnapshot.value;
    final startersCount = controller
        .lineupDrafts.values
        .where((value) => value == MatchdayLineupSlot.starter.name)
        .length;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('2. قفل التشكيل', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            controller.requiredStarterCount == null
                ? 'اختر أساسيًا واحدًا على الأقل ثم اقفل التشكيل.'
                : 'الأساسيون المختارون: $startersCount / ${controller.requiredStarterCount}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (snapshot != null) ...[
            _SnapshotReadonlyView(snapshot: snapshot),
          ] else ...[
            ...controller.participants.map(
              (participant) => _LineupParticipantTile(
                controller: controller,
                participant: participant,
                enabled: controller.canEditPreKickoff &&
                    !controller.isSubmitting.value,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.canEditPreKickoff &&
                        !controller.isSubmitting.value
                    ? controller.lockLineup
                    : null,
                icon: const Icon(Icons.lock_outline),
                label: const Text('قفل التشكيل'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubstitutionSection extends StatelessWidget {
  final MatchdayController controller;

  const _SubstitutionSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.activeSnapshot.value;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3. التبديلات', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(
            snapshot == null
                ? 'لا يمكن تسجيل تبديلات قبل قفل التشكيل.'
                : 'اختر لاعبًا خارجًا وآخر بديلًا من نفس التشكيل المقفول.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (snapshot == null)
            const _SectionHint(message: 'اقفل التشكيل أولًا لتفعيل سجل التبديلات.')
          else ...[
            _SubstitutionDropdown(
              label: 'اللاعب الخارج',
              value: _safeDropdownValue(
                selectedValue: controller.selectedOutgoingAttendanceId.value,
                items: controller.currentOnPitchAttendances
                    .map((attendance) => attendance.id)
                    .toSet(),
              ),
              items: controller.currentOnPitchAttendances
                  .map(
                    (attendance) => DropdownMenuItem<String>(
                      value: attendance.id,
                      child: Text(controller.substitutionLabel(attendance.id)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: controller.isSubmitting.value
                  ? null
                  : (value) => controller.selectedOutgoingAttendanceId.value = value,
            ),
            const SizedBox(height: AppDimensions.sm),
            _SubstitutionDropdown(
              label: 'البديل',
              value: _safeDropdownValue(
                selectedValue: controller.selectedIncomingAttendanceId.value,
                items: controller.availableIncomingAttendances
                    .map((attendance) => attendance.id)
                    .toSet(),
              ),
              items: controller.availableIncomingAttendances
                  .map(
                    (attendance) => DropdownMenuItem<String>(
                      value: attendance.id,
                      child: Text(controller.substitutionLabel(attendance.id)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: controller.isSubmitting.value
                  ? null
                  : (value) => controller.selectedIncomingAttendanceId.value = value,
            ),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: controller.substitutionMinuteController,
              enabled: !controller.isSubmitting.value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'دقيقة التبديل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : controller.recordSubstitution,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('تسجيل التبديل'),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          Text('سجل التبديلات', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.sm),
          if (controller.sideSubstitutions.isEmpty)
            const _SectionHint(message: 'لا توجد تبديلات مسجلة حتى الآن.')
          else
            ...controller.sideSubstitutions.map(
              (substitution) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warning.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Text(
                          "${substitution.minute}'",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.error),
                              const SizedBox(width: 4),
                              Text(
                                controller.substitutionLabel(substitution.outgoingAttendanceId),
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(
                                controller.substitutionLabel(substitution.incomingAttendanceId),
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.success),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ParticipantAttendanceTile extends StatelessWidget {
  final MatchdayController controller;
  final MatchdayParticipantDraft participant;
  final bool enabled;

  const _ParticipantAttendanceTile({
    required this.controller,
    required this.participant,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final currentStatus = controller.statusFor(participant.selectionId);
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AttendanceAvatar(
                name: participant.displayName,
                status: currentStatus,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.displayName,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        if (participant.isGuest)
                          const _StatusBadge(label: 'ضيف', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        participant.position,
                        participant.statusSeedLabel,
                      ].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MatchAttendanceStatus.values
                .map(
                  (status) => ChoiceChip(
                    label: Text(_attendanceStatusLabel(status)),
                    selected: currentStatus == status,
                    selectedColor: _attendanceChipColor(status),
                    onSelected: enabled
                        ? (_) => controller.setAttendanceStatus(
                              participant.selectionId,
                              status,
                            )
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _LineupParticipantTile extends StatelessWidget {
  final MatchdayController controller;
  final MatchdayParticipantDraft participant;
  final bool enabled;

  const _LineupParticipantTile({
    required this.controller,
    required this.participant,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final slot = controller.lineupSlotFor(participant.selectionId);
    final isEligible = controller.statusFor(participant.selectionId) ==
            MatchAttendanceStatus.present ||
        controller.statusFor(participant.selectionId) == MatchAttendanceStatus.late;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  participant.displayName,
                  style: AppTextStyles.titleMedium,
                ),
              ),
              if (participant.isGuest)
                const _StatusBadge(label: 'ضيف', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            isEligible
                ? 'مؤهل للتشكيل'
                : 'لاعب غير مؤهل قبل تأكيد حضوره.',
            style: AppTextStyles.labelSmall.copyWith(
              color: isEligible ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('خارج التشكيل'),
                selected: slot == null,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          null,
                        )
                    : null,
              ),
              ChoiceChip(
                label: const Text('أساسي'),
                selected: slot == MatchdayLineupSlot.starter,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          MatchdayLineupSlot.starter,
                        )
                    : null,
              ),
              ChoiceChip(
                label: const Text('احتياط'),
                selected: slot == MatchdayLineupSlot.bench,
                onSelected: enabled && isEligible
                    ? (_) => controller.setLineupSlot(
                          participant.selectionId,
                          MatchdayLineupSlot.bench,
                        )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotReadonlyView extends StatelessWidget {
  final MatchLineupSnapshot snapshot;

  const _SnapshotReadonlyView({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusBadge(label: snapshot.summaryLabel, color: AppColors.success),
        const SizedBox(height: AppDimensions.sm),
        Text('الأساسيون', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.xs),
        ...snapshot.starters.map(
          (entry) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: Text(entry.displayName),
            subtitle: Text(entry.position ?? 'بدون مركز'),
            trailing: entry.isGuest
                ? const _StatusBadge(label: 'ضيف', color: AppColors.warning)
                : null,
          ),
        ),
        if (snapshot.bench.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.sm),
          Text('الاحتياط', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppDimensions.xs),
          ...snapshot.bench.map(
            (entry) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(entry.displayName),
              subtitle: Text(entry.position ?? 'بدون مركز'),
              trailing: entry.isGuest
                  ? const _StatusBadge(label: 'ضيف', color: AppColors.warning)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoManagedSideCard extends StatelessWidget {
  final MatchdayController controller;

  const _NoManagedSideCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final message = controller.isLoggedIn
        ? 'لا توجد أطراف تملك صلاحية إدارتها في هذه المباراة من حسابك الحالي.'
        : 'سجّل الدخول أولًا حتى تظهر لك أطراف المباراة التي يمكنك إدارتها.';
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(AppDimensions.lg),
      borderRadius: AppDimensions.radiusLg,
      child: Column(
        children: [
          const Icon(Icons.sports_soccer_outlined, size: 42),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'لا يوجد طرف متاح حاليًا',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String message;

  const _SectionHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(message, style: AppTextStyles.bodyMedium),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}


class _SubstitutionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  const _SubstitutionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: onChanged != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

String _attendanceStatusLabel(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.pending => 'انتظار',
    MatchAttendanceStatus.present => 'حاضر',
    MatchAttendanceStatus.late => 'متأخر',
    MatchAttendanceStatus.absent => 'غائب',
    MatchAttendanceStatus.excused => 'معذور',
  };
}

String? _safeDropdownValue({
  required String? selectedValue,
  required Set<String> items,
}) {
  if (selectedValue == null || !items.contains(selectedValue)) {
    return null;
  }
  return selectedValue;
}



Color _attendanceChipColor(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.present => AppColors.success.withValues(alpha: 0.2),
    MatchAttendanceStatus.late => AppColors.warning.withValues(alpha: 0.2),
    MatchAttendanceStatus.absent => AppColors.error.withValues(alpha: 0.2),
    MatchAttendanceStatus.excused => AppColors.info.withValues(alpha: 0.2),
    MatchAttendanceStatus.pending => AppColors.surface,
  };
}

Color _attendanceStatusColor(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.present => AppColors.success,
    MatchAttendanceStatus.late => AppColors.warning,
    MatchAttendanceStatus.absent => AppColors.error,
    MatchAttendanceStatus.excused => AppColors.info,
    MatchAttendanceStatus.pending => AppColors.textMuted,
  };
}

class _AttendanceAvatar extends StatelessWidget {
  final String name;
  final MatchAttendanceStatus status;

  const _AttendanceAvatar({required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _attendanceStatusColor(status);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

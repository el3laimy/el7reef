import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/matchday_controller.dart';
import 'matchday_section_hint.dart';
import 'matchday_substitution_dropdown.dart';

class MatchdaySubstitutionSection extends StatelessWidget {
  final MatchdayController controller;

  const MatchdaySubstitutionSection({super.key, required this.controller});

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
            const MatchdaySectionHint(
              message: 'اقفل التشكيل أولًا لتفعيل سجل التبديلات.',
            )
          else ...[
            MatchdaySubstitutionDropdown(
              label: 'اللاعب الخارج',
              value: safeDropdownValue(
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
                  : (value) =>
                      controller.selectedOutgoingAttendanceId.value = value,
            ),
            const SizedBox(height: AppDimensions.sm),
            MatchdaySubstitutionDropdown(
              label: 'البديل',
              value: safeDropdownValue(
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
                  : (value) =>
                      controller.selectedIncomingAttendanceId.value = value,
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
            const MatchdaySectionHint(message: 'لا توجد تبديلات مسجلة حتى الآن.')
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
                          Text(
                            '${controller.substitutionLabel(substitution.outgoingAttendanceId)} ⟶ ${controller.substitutionLabel(substitution.incomingAttendanceId)}',
                            style: AppTextStyles.labelMedium,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 14,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                controller.substitutionLabel(
                                  substitution.outgoingAttendanceId,
                                ),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                controller.substitutionLabel(
                                  substitution.incomingAttendanceId,
                                ),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.success,
                                ),
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/el7reef_button.dart';
import '../../../core/widgets/glassmorphic_container.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_dialogs.dart';
import 'team_roster_snapshot_card.dart';
import 'team_roster_template_card.dart';

class TeamRosterFormationWorkspace extends StatelessWidget {
  final TeamRosterController controller;

  const TeamRosterFormationWorkspace({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      borderRadius: AppDimensions.radiusXl,
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  'القوالب والنسخ الجاهزة',
                  style: AppTextStyles.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'الوضع الحالي: ${controller.currentFormationSummary}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.md),
          if (controller.canManageRoster)
            Row(
              children: [
                Expanded(
                  child: El7reefButton(
                    text: 'حفظ كقالب',
                    icon: Icons.save_alt_rounded,
                    onPressed: () => showTemplateSheet(context, controller),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: El7reefButton(
                    text: 'إنشاء نسخة',
                    icon: Icons.content_copy_rounded,
                    isOutlined: true,
                    onPressed: () => showSnapshotSheet(context, controller),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.lg),
          Text('القوالب المحفوظة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Obx(() {
            if (controller.formationTemplates.isEmpty) {
              return Text(
                'لا توجد قوالب محفوظة بعد. احفظ التشكيلة الحالية لتعيد استخدامها لاحقًا.',
                style: AppTextStyles.bodySmall,
              );
            }

            return Column(
              children: controller.formationTemplates
                  .map(
                    (template) => TeamRosterTemplateCard(
                      template: template,
                      controller: controller,
                      canManageRoster: controller.canManageRoster,
                    ),
                  )
                  .toList(growable: false),
            );
          }),
          const SizedBox(height: AppDimensions.lg),
          Text('النسخ الجاهزة', style: AppTextStyles.titleLarge),
          const SizedBox(height: AppDimensions.sm),
          Obx(() {
            if (controller.rosterSnapshots.isEmpty) {
              return Text(
                'لم يتم إنشاء أي نسخة جاهزة للمباراة بعد.',
                style: AppTextStyles.bodySmall,
              );
            }

            return Column(
              children: controller.rosterSnapshots
                  .map(
                    (snapshot) => TeamRosterSnapshotCard(snapshot: snapshot),
                  )
                  .toList(growable: false),
            );
          }),
        ],
      ),
    );
  }
}
